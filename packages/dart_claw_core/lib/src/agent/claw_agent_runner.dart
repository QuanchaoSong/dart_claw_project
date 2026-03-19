import 'dart:async';

import 'package:flutter/foundation.dart';

import '../llm/claw_llm_client.dart';
import '../llm/claw_llm_delta.dart';
import '../model/agent_event.dart';
import '../model/chat_block.dart';
import '../model/chat_message.dart';
import '../model/tool_call_record.dart';
import '../skill/claw_skill_info.dart';
import '../skill/claw_skill_loader.dart';
import '../skill/claw_skill_matcher.dart';
import '../tools/builtin_tools.dart';
import '../tools/claw_tool.dart';

/// Agent loop 核心：组装 prompt → 调用 LLM → 执行工具 → 循环，直到无工具调用
class ClawAgentRunner {
  final ClawLlmClient client;

  /// 已注册的工具列表（可在外部扩展）
  final List<ClawTool> tools;

  static const _baseSystemPrompt = '''
You are dart Claw, an expert AI coding assistant running on the user's local machine.
You help users with programming tasks.

IMPORTANT RULES:
- When asked about system info, file contents, or anything that requires inspecting the machine, you MUST call the appropriate tool instead of guessing or describing.
- When asked to modify files, always read them first with read_file, then write with write_file.
- For dangerous operations (run_command, write_file), briefly state what you are about to do before calling the tool.
- When all tasks are done, provide a concise summary.
- Be direct and practical. Avoid unnecessary explanations.''';

  ClawAgentRunner({
    required this.client,
    List<ClawTool>? tools,
  }) : tools = tools ??
            [
              RunCommandTool(),
              ReadFileTool(),
              WriteFileTool(),
              ListDirTool(),
              SearchInFileTool(),
            ];

  /// 等待用户确认的 Completer 映射表（requestId → Completer<bool>）
  final Map<String, Completer<bool>> _pendingConfirms = {};

  /// 取消标志：外部调用 [cancel] 后置 true，loop 在下一检查点退出
  bool _cancelled = false;

  /// UI 层调用：中止当前 Agent loop
  void cancel() {
    _cancelled = true;
    for (final c in _pendingConfirms.values) {
      if (!c.isCompleted) c.complete(false);
    }
    _pendingConfirms.clear();
  }

  /// UI 层调用：用户对确认请求给出答复
  void confirm(String requestId, {required bool allow}) {
    _pendingConfirms[requestId]?.complete(allow);
  }

  /// 运行 Agent 对话：LLM → 工具执行 → 再次 LLM → 循环，最多 [maxRounds] 轮
  ///
  /// 如果用户显式传入 [explicitSkillName]，跳过自动匹配直接使用对应 skill。
  Stream<ClawAgentEvent> run({
    required String userMessage,
    List<ClawChatMessage> history = const [],
    String? assistantMessageId,
    int maxRounds = 20,
    String? explicitSkillName,
  }) async* {
    _cancelled = false;
    final assistantId = assistantMessageId ?? _genId();
    final toolDefs = tools.map((t) => t.definition).toList();
    final toolMap = {for (final t in tools) t.name: t};

    // ─── Skill 匹配阶段 ──────────────────────────────────────────────────────
    ClawSkillMatch? skillMatch;
    try {
      final availableSkills = await ClawSkillLoader.loadAll();
      if (availableSkills.isNotEmpty) {
        if (explicitSkillName != null) {
          // 手动指定：直接查找目标 skill，参数由 LLM 提取
          final target =
              availableSkills.where((s) => s.name == explicitSkillName).firstOrNull;
          if (target != null) {
            skillMatch = await ClawSkillMatcher(client: client).match(
              userTask: userMessage,
              availableSkills: [target],
            );
          }
        } else {
          // 自动匹配
          yield ClawAgentLogEvent('匹配 Skill…');
          skillMatch = await ClawSkillMatcher(client: client).match(
            userTask: userMessage,
            availableSkills: availableSkills,
          );
        }
      }
    } catch (e) {
      debugPrint('[ClawAgentRunner] Skill matching failed: $e');
      // 匹配失败不阻断任务，继续按普通流程执行
    }

    // ─── 构建 system prompt ──────────────────────────────────────────────────
    String systemPrompt = _baseSystemPrompt;
    List<ClawSkillStep> skillSteps = [];

    if (skillMatch != null) {
      final resolvedContent = skillMatch.skill.resolveAndFormat(skillMatch.params);
      skillSteps = skillMatch.skill.steps;
      systemPrompt = '''
$_baseSystemPrompt

---

You are currently executing a SKILL. Follow the rules below WITHOUT EXCEPTION:
1. Execute ONLY the steps defined in the skill, in order. Do NOT introduce tools or methods not listed in a step's "Expected tools".
2. If any step fails (non-zero exit code or error output), you MUST stop immediately. Do NOT try alternative approaches.
3. Report failures exactly as specified in the step's "Failure report" field.

$resolvedContent''';

      yield ClawAgentSkillActivatedEvent(skillMatch.skill.name, resolvedContent);
    }

    final apiMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      for (final msg in history)
        if (msg.role != ClawChatMessageRole.system)
          ...msg.toApiMessages(),
      {'role': 'user', 'content': userMessage},
    ];

    yield ClawAgentLogEvent('调用 ${client.modelId}…');

    // 追踪当前处理到第几个 skill 步骤
    int skillStepIndex = 0;

    try {
      for (var round = 0; round < maxRounds; round++) {
        String fullContent = '';
        String reasoningContent = '';
        List<ClawToolCallRecord> pendingToolCalls = [];
        ClawChatBlockType? lastBlockType;

        await for (final delta in client.streamChat(
          messages: apiMessages,
          tools: toolDefs.isEmpty ? null : toolDefs,
        )) {
          if (_cancelled) break;
          switch (delta) {
            case ClawLlmTextDelta(:final text):
              if (lastBlockType != ClawChatBlockType.content) {
                yield ClawAgentNewBlockEvent(assistantId, ClawChatBlockType.content);
                lastBlockType = ClawChatBlockType.content;
              }
              fullContent += text;
              yield ClawAgentMessageChunkEvent(assistantId, text);
            case ClawLlmReasoningDelta(:final text):
              if (lastBlockType != ClawChatBlockType.reasoning) {
                yield ClawAgentNewBlockEvent(assistantId, ClawChatBlockType.reasoning);
                lastBlockType = ClawChatBlockType.reasoning;
              }
              reasoningContent += text;
              yield ClawAgentReasoningChunkEvent(assistantId, text);
            case ClawLlmToolCallsDelta(:final toolCalls):
              pendingToolCalls = toolCalls;
              for (final tc in toolCalls) {
                yield ClawAgentToolEvent(tc);
              }
            case ClawLlmFinishDelta():
              break;
          }
        }

        yield ClawAgentMessageDoneEvent(assistantId, toolCalls: pendingToolCalls);

        if (_cancelled) return;

        final assistantEntry = <String, dynamic>{
          'role': 'assistant',
          'content': fullContent.isEmpty ? null : fullContent,
        };
        if (reasoningContent.isNotEmpty) {
          assistantEntry['reasoning_content'] = reasoningContent;
        }
        if (pendingToolCalls.isNotEmpty) {
          assistantEntry['tool_calls'] =
              pendingToolCalls.map((tc) => tc.toApiJson()).toList();
        }
        apiMessages.add(assistantEntry);

        if (pendingToolCalls.isEmpty) {
          yield ClawAgentDoneEvent(fullContent);
          return;
        }

        // ─── 工具执行阶段 ──────────────────────────────────────────────────
        for (final tc in pendingToolCalls) {
          if (_cancelled) return;

          final tool = toolMap[tc.name];

          // 工具不存在
          if (tool == null) {
            const errMsg = 'Unknown tool';
            apiMessages.add({
              'role': 'tool',
              'tool_call_id': tc.id,
              'content': '[error] $errMsg: ${tc.name}',
            });
            yield ClawAgentToolEvent(
                tc.copyWith(status: ClawToolStatus.error, result: errMsg));
            continue;
          }

          // Skill 模式：工具偏离检测
          if (skillMatch != null && skillSteps.isNotEmpty) {
            final currentStep =
                skillSteps[skillStepIndex.clamp(0, skillSteps.length - 1)];
            if (currentStep.expectedTools.isNotEmpty &&
                !currentStep.expectedTools.contains(tc.name)) {
              yield ClawAgentToolEvent(tc.copyWith(
                  status: ClawToolStatus.error,
                  result: 'Unexpected tool for this skill step'));
              yield ClawAgentSkillStepFailureEvent(
                skillName: skillMatch.skill.name,
                stepTitle: currentStep.title,
                toolName: tc.name,
                toolOutput: '',
                failureReport: currentStep.failureReport,
                reason: ClawSkillFailureReason.unexpectedTool,
              );
              return;
            }
          }

          // 高危操作：等待用户确认
          if (tool.isDangerous) {
            final requestId = _genId();
            final completer = Completer<bool>();
            _pendingConfirms[requestId] = completer;

            yield ClawAgentToolEvent(tc.copyWith(
              status: ClawToolStatus.awaitingConfirmation,
              confirmRequestId: requestId,
            ));
            yield ClawAgentConfirmRequestEvent(requestId, tc.name, tc);

            final allowed = await completer.future;
            _pendingConfirms.remove(requestId);

            if (_cancelled) return;

            if (!allowed) {
              const denial = 'Denied by user';
              apiMessages.add({
                'role': 'tool',
                'tool_call_id': tc.id,
                'content': '[denied by user]',
              });
              yield ClawAgentToolEvent(
                  tc.copyWith(status: ClawToolStatus.error, result: denial));
              continue;
            }
          }

          yield ClawAgentToolEvent(tc.copyWith(status: ClawToolStatus.running));

          try {
            final result = await tool.execute(tc.args);
            debugPrint('[dart_claw] tool ${tc.name} → ${result.output.substring(0, result.output.length.clamp(0, 200))}');

            apiMessages.add({
              'role': 'tool',
              'tool_call_id': tc.id,
              'content': result.output,
            });
            yield ClawAgentToolEvent(
                tc.copyWith(status: ClawToolStatus.success, result: result.output));

            // Skill 模式：工具失败拦截（应用层，LLM 没机会绕路）
            if (skillMatch != null && !result.isSuccess && skillSteps.isNotEmpty) {
              final currentStep =
                  skillSteps[skillStepIndex.clamp(0, skillSteps.length - 1)];
              yield ClawAgentSkillStepFailureEvent(
                skillName: skillMatch.skill.name,
                stepTitle: currentStep.title,
                toolName: tc.name,
                toolOutput: result.output,
                failureReport: currentStep.failureReport,
                reason: ClawSkillFailureReason.toolFailed,
              );
              return; // 立即中止，不给 LLM 继续决策的机会
            }

            // 步骤成功，推进步骤指针
            if (skillMatch != null && skillSteps.isNotEmpty) {
              skillStepIndex = (skillStepIndex + 1).clamp(0, skillSteps.length - 1);
            }
          } catch (e) {
            final errMsg = 'Tool execution failed: $e';
            debugPrint('[dart_claw] tool ${tc.name} error: $e');
            apiMessages.add({
              'role': 'tool',
              'tool_call_id': tc.id,
              'content': errMsg,
            });
            yield ClawAgentToolEvent(
                tc.copyWith(status: ClawToolStatus.error, result: errMsg));

            // Skill 模式：异常也视为失败，立即中止
            if (skillMatch != null && skillSteps.isNotEmpty) {
              final currentStep =
                  skillSteps[skillStepIndex.clamp(0, skillSteps.length - 1)];
              yield ClawAgentSkillStepFailureEvent(
                skillName: skillMatch.skill.name,
                stepTitle: currentStep.title,
                toolName: tc.name,
                toolOutput: errMsg,
                failureReport: currentStep.failureReport,
                reason: ClawSkillFailureReason.toolFailed,
              );
              return;
            }
          }
        }

        if (_cancelled) return;
        yield ClawAgentLogEvent('工具执行完毕，继续调用 ${client.modelId}…');
      }

      yield ClawAgentErrorEvent('已执行 $maxRounds 轮工具调用，自动终止。');
    } on ClawLlmException catch (e) {
      yield ClawAgentErrorEvent('LLM 调用失败（${e.statusCode}）：${e.message}');
    } catch (e, st) {
      yield ClawAgentErrorEvent('意外错误：$e\n$st');
    }
  }
}

String _genId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  return (now ^ (now >> 16)).toRadixString(36);
}
