import '../llm/claw_llm_client.dart';
import '../llm/claw_llm_delta.dart';
import '../model/agent_event.dart';
import '../model/chat_message.dart';
import '../model/tool_call_record.dart';

/// Agent loop 核心：组装 prompt → 调用 LLM → 解析 tool_call → 发出事件流
///
/// 当前阶段（二）：只处理纯文本对话，tool_call 解析完成但执行留待阶段三。
class ClawAgentRunner {
  final ClawLlmClient client;

  /// 编码助手系统 prompt
  static const _systemPrompt = '''
Your name is Dart Claw, an expert AI coding assistant running on the user's local machine.
You help users with programming tasks: reading and writing files, executing shell commands, navigating codebases, debugging, and explaining concepts.

Guidelines:
- Be concise and practical.
- Before editing a file, read it first to understand the context.
- For dangerous operations (deleting files, running scripts), explain what you are about to do before proceeding.
- When a task is complete, provide a brief summary of what was done.''';

  ClawAgentRunner({required this.client});

  /// 运行一轮 Agent 对话，返回 [ClawAgentEvent] 事件流
  ///
  /// [userMessage]         本轮用户消息内容
  /// [history]             历史消息列表（不含本轮用户消息）
  /// [assistantMessageId]  调用方预先创建的 assistant 占位消息 id（用于流式显示）
  /// [tools]               传给 LLM 的工具定义列表（阶段三填入）
  Stream<ClawAgentEvent> run({
    required String userMessage,
    List<ClawChatMessage> history = const [],
    String? assistantMessageId,
    List<Map<String, dynamic>> tools = const [],
  }) async* {
    final assistantId = assistantMessageId ?? _genId();

    // ── 构建 messages 列表 ────────────────────────────────────────────────
    final apiMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _systemPrompt},
      for (final msg in history)
        if (msg.role != ClawChatMessageRole.system) msg.toApiJson(),
      {'role': 'user', 'content': userMessage},
    ];

    yield ClawAgentLogEvent('调用 ${client.modelId}…');

    try {
      String fullContent = '';
      List<ClawToolCallRecord> pendingToolCalls = [];

      // ── 流式调用 LLM ──────────────────────────────────────────────────
      await for (final delta in client.streamChat(
        messages: apiMessages,
        tools: tools.isEmpty ? null : tools,
      )) {
        switch (delta) {
          case ClawLlmTextDelta(:final text):
            fullContent += text;
            yield ClawAgentMessageChunkEvent(assistantId, text);

          case ClawLlmToolCallsDelta(:final toolCalls):
            pendingToolCalls = toolCalls;
            // 通知 UI：有工具调用待执行（状态 pending）
            for (final tc in toolCalls) {
              yield ClawAgentToolEvent(tc);
            }

          case ClawLlmFinishDelta():
            break;
        }
      }

      yield ClawAgentMessageDoneEvent(assistantId, toolCalls: pendingToolCalls);

      if (pendingToolCalls.isEmpty) {
        // 纯文本回复，本轮结束
        yield ClawAgentDoneEvent(fullContent);
      } else {
        // TODO(阶段三)：依次执行工具 → 回填结果 → 再次调用 LLM → 循环
        yield ClawAgentDoneEvent('工具调用已解析，执行能力将在阶段三实现。');
      }
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
