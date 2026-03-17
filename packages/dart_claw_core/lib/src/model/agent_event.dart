import 'tool_call_record.dart';

/// Agent loop 向外发出的事件流
///
/// 使用 sealed class，调用方可用 switch/pattern matching 穷举处理。
sealed class ClawAgentEvent {}

/// 普通日志（如 "正在读取文件…"）
class ClawAgentLogEvent extends ClawAgentEvent {
  final String content;
  ClawAgentLogEvent(this.content);
}

/// LLM 流式输出的文本片段
class ClawAgentMessageChunkEvent extends ClawAgentEvent {
  /// 对应的 assistant 消息 id（用于定位并追加到正确的消息）
  final String messageId;
  final String chunk;
  ClawAgentMessageChunkEvent(this.messageId, this.chunk);
}

/// LLM 思考过程片段（DeepSeek Reasoner 等模型的 reasoning_content）
class ClawAgentReasoningChunkEvent extends ClawAgentEvent {
  final String messageId;
  final String chunk;
  ClawAgentReasoningChunkEvent(this.messageId, this.chunk);
}

/// LLM 当前这轮输出完毕（流式结束），附带完整 tool_calls（如有）
class ClawAgentMessageDoneEvent extends ClawAgentEvent {
  final String messageId;
  final List<ClawToolCallRecord> toolCalls;
  ClawAgentMessageDoneEvent(this.messageId, {this.toolCalls = const []});
}

/// 工具调用状态变更（pending → running → success/error）
class ClawAgentToolEvent extends ClawAgentEvent {
  final ClawToolCallRecord record;
  ClawAgentToolEvent(this.record);
}

/// 高危操作需要用户确认
class ClawAgentConfirmRequestEvent extends ClawAgentEvent {
  /// 确认请求的唯一 id，用于回传 [ClawAgentRunner.confirm]
  final String requestId;

  /// 展示给用户的描述文字
  final String message;

  /// 对应的工具调用记录
  final ClawToolCallRecord record;

  ClawAgentConfirmRequestEvent(this.requestId, this.message, this.record);
}

/// 整个任务完成
class ClawAgentDoneEvent extends ClawAgentEvent {
  final String summary;
  ClawAgentDoneEvent(this.summary);
}

/// 出现无法恢复的错误
class ClawAgentErrorEvent extends ClawAgentEvent {
  final String message;
  ClawAgentErrorEvent(this.message);
}
