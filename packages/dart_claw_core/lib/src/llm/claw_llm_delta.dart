import '../model/tool_call_record.dart';

/// LLM SSE 流的单次 delta 事件
sealed class ClawLlmDelta {
  const ClawLlmDelta();
}

/// LLM 输出的文本片段
class ClawLlmTextDelta extends ClawLlmDelta {
  final String text;
  const ClawLlmTextDelta(this.text);
}

/// LLM 的思考过程片段（DeepSeek Reasoner 等模型 reasoning_content）
/// 与正文分开，以便回填 assistant 消息时放入正确字段
class ClawLlmReasoningDelta extends ClawLlmDelta {
  final String text;
  const ClawLlmReasoningDelta(this.text);
}

/// 流结束后，完整组装好的 tool_calls 列表
class ClawLlmToolCallsDelta extends ClawLlmDelta {
  final List<ClawToolCallRecord> toolCalls;
  const ClawLlmToolCallsDelta(this.toolCalls);
}

/// 流结束信号
class ClawLlmFinishDelta extends ClawLlmDelta {
  final String? reason; // 'stop' | 'tool_calls' | null
  const ClawLlmFinishDelta(this.reason);
}
