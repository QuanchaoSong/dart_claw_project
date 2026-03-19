import 'chat_block.dart';
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

/// Runner 开始产生新 block（reasoning 或 content），UI 应在消息中追加对应空 block
class ClawAgentNewBlockEvent extends ClawAgentEvent {
  final String messageId;
  final ClawChatBlockType blockType;
  ClawAgentNewBlockEvent(this.messageId, this.blockType);
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

/// Skill 被激活（匹配成功后 emit 一次，供 UI 显示当前激活的 skill 名称）
class ClawAgentSkillActivatedEvent extends ClawAgentEvent {
  /// 激活的 skill name
  final String skillName;

  /// 参数占位符已替换后的 skill 全文（已注入 system prompt）
  final String resolvedContent;

  ClawAgentSkillActivatedEvent(this.skillName, this.resolvedContent);
}

/// Skill 某步骤失败，整个任务中止
///
/// UI 应弹出结构化失败报告，而不是普通错误弹窗。
class ClawAgentSkillStepFailureEvent extends ClawAgentEvent {
  /// 激活的 skill name
  final String skillName;

  /// 失败的步骤标题
  final String stepTitle;

  /// 调用的工具名（偏离检测时可能与预期不同）
  final String toolName;

  /// 工具返回的原始输出
  final String toolOutput;

  /// Skill 文件中预设的失败报告文案
  final String failureReport;

  /// 失败原因分类
  final ClawSkillFailureReason reason;

  ClawAgentSkillStepFailureEvent({
    required this.skillName,
    required this.stepTitle,
    required this.toolName,
    required this.toolOutput,
    required this.failureReport,
    required this.reason,
  });
}

enum ClawSkillFailureReason {
  /// 工具执行结果 isSuccess == false（exit code != 0 或返回 [error]）
  toolFailed,

  /// LLM 调用了 skill 步骤中未列出的工具
  unexpectedTool,
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
