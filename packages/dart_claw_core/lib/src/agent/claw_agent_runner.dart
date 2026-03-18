import 'dart:async';

import 'package:flutter/foundation.dart';

import '../llm/claw_llm_client.dart';
import '../llm/claw_llm_delta.dart';
import '../model/agent_event.dart';
import '../model/chat_block.dart';
import '../model/chat_message.dart';
import '../model/tool_call_record.dart';
import '../tools/builtin_tools.dart';
import '../tools/claw_tool.dart';

/// Agent loop 核心：组装 prompt → 调用 LLM → 执行工具 → 循环，直到无工具调用
///
/// 阶段三：完整工具执行 loop，支持多轮 LLM ↔ 工具调用。
class ClawAgentRunner {
  final ClawLlmClient client;

  /// 已注册的工具列表（可在外部扩展）
  final List<ClawTool> tools;

  static const _systemPrompt = '''
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
  /// 同时拒绝所有等待确认的工具调用，解除 Completer 阻塞。
  void cancel() {
    _cancelled = true;
    for (final c in _pendingConfirms.values) {
      if (!c.isCompleted) c.complete(false);
    }
    _pendingConfirms.clear();
  }

  /// UI 层调用：用户对确认请求给出答复
  /// [allow] = true 表示允许，false 表示拒绝
  void confirm(String requestId, {required bool allow}) {
    _pendingConfirms[requestId]?.complete(allow);
  }

  /// 运行 Agent 对话：LLM → 工具执行 → 再次 LLM → 循环，最多 [maxRounds] 轮
  Stream<ClawAgentEvent> run({
    required String userMessage,
    List<ClawChatMessage> history = const [],
    String? assistantMessageId,
    int maxRounds = 10,
  }) async* {
    _cancelled = false;   // 每次 run 重置取消标志
    final assistantId = assistantMessageId ?? _genId();

    final toolDefs = tools.map((t) => t.definition).toList();
    final toolMap = {for (final t in tools) t.name: t};

    final apiMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _systemPrompt},
      for (final msg in history)
        if (msg.role != ClawChatMessageRole.system)
          ...msg.toApiMessages(),
      {'role': 'user', 'content': userMessage},
    ];

    yield ClawAgentLogEvent('调用 ${client.modelId}…');

    try {
      for (var round = 0; round < maxRounds; round++) {
        // 所有轮次始终复用同一个 assistantId，保证 UI 只有一个气泡
        String fullContent = '';
        String reasoningContent = '';
        List<ClawToolCallRecord> pendingToolCalls = [];

        // 追踪当前 block 类型，发生切换时先 emit NewBlockEvent
        ClawChatBlockType? lastBlockType;

        await for (final delta in client.streamChat(
          messages: apiMessages,
          tools: toolDefs.isEmpty ? null : toolDefs,
        )) {
          if (_cancelled) break;   // 流式输出中途取消
          switch (delta) {
            case ClawLlmTextDelta(:final text):
              if (lastBlockType != ClawChatBlockType.content) {
                yield ClawAgentNewBlockEvent(
                    assistantId, ClawChatBlockType.content);
                lastBlockType = ClawChatBlockType.content;
              }
              fullContent += text;
              yield ClawAgentMessageChunkEvent(assistantId, text);
            case ClawLlmReasoningDelta(:final text):
              if (lastBlockType != ClawChatBlockType.reasoning) {
                yield ClawAgentNewBlockEvent(
                    assistantId, ClawChatBlockType.reasoning);
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

        yield ClawAgentMessageDoneEvent(
          assistantId,
          toolCalls: pendingToolCalls,
        );

        if (_cancelled) return;   // streaming 结束后检查

        // 把 assistant 本轮回复追加到 messages 供下一轮使用
        // DeepSeek Reasoner 要求 assistant 消息必须带 reasoning_content 字段
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

        // 无工具调用：对话结束
        if (pendingToolCalls.isEmpty) {
          yield ClawAgentDoneEvent(fullContent);
          return;
        }

        // 依次执行所有工具
        for (final tc in pendingToolCalls) {
          final tool = toolMap[tc.name];
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

          // 高危操作：先暂停并等待用户确认
          if (tool.isDangerous) {
            final requestId = _genId();
            final completer = Completer<bool>();
            _pendingConfirms[requestId] = completer;

            // 更新 block 状态为 awaitingConfirmation，并嵌入 requestId 供 UI 使用
            yield ClawAgentToolEvent(tc.copyWith(
              status: ClawToolStatus.awaitingConfirmation,
              confirmRequestId: requestId,
            ));
            yield ClawAgentConfirmRequestEvent(requestId, tc.name, tc);

            final allowed = await completer.future;
            _pendingConfirms.remove(requestId);

            // 用户取消或 cancel() 强制拒绝
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
            debugPrint('[dart_claw] tool ${tc.name} → ${result.substring(0, result.length.clamp(0, 200))}');
            apiMessages.add({
              'role': 'tool',
              'tool_call_id': tc.id,
              'content': result,
            });
            yield ClawAgentToolEvent(
                tc.copyWith(status: ClawToolStatus.success, result: result));
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
          }
        }

        if (_cancelled) return;   // 工具执行完毕后检查
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
