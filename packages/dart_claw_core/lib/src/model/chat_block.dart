import 'tool_call_record.dart';

/// 一个 assistant 消息由有序 block 列表组成，每种 block 对应一个阶段的输出。
/// 多轮工具调用时，新的 reasoning/content block 会追加到列表末尾，而不是覆盖旧的。
sealed class ClawChatBlock {
  const ClawChatBlock();

  // ─── 持久化序列化 ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson();

  factory ClawChatBlock.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'reasoning' => ClawReasoningBlock(
          content: json['content'] as String? ?? '',
          isStreaming: false,
        ),
      'content' => ClawContentBlock(
          content: json['content'] as String? ?? '',
          isStreaming: false,
        ),
      'tool_call' => ClawToolCallBlock(
          record: ClawToolCallRecord.fromJson(
              json['record'] as Map<String, dynamic>),
        ),
      _ => throw FormatException('Unknown ClawChatBlock type: $type'),
    };
  }
}

// ─── Reasoning block ──────────────────────────────────────────────────────────

/// LLM 推理过程片段（DeepSeek Reasoner 等模型的 reasoning_content）
class ClawReasoningBlock extends ClawChatBlock {
  final String content;

  /// true = 仍在流式输出；false = 该 block 已结束
  final bool isStreaming;

  const ClawReasoningBlock({this.content = '', this.isStreaming = true});

  ClawReasoningBlock copyWith({String? content, bool? isStreaming}) =>
      ClawReasoningBlock(
        content: content ?? this.content,
        isStreaming: isStreaming ?? this.isStreaming,
      );

  ClawReasoningBlock appendChunk(String chunk) =>
      copyWith(content: content + chunk);

  ClawReasoningBlock finalize() => copyWith(isStreaming: false);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'reasoning',
        'content': content,
      };
}

// ─── Content block ────────────────────────────────────────────────────────────

/// LLM 正文输出（每轮 LLM 调用产生一个 content block）
class ClawContentBlock extends ClawChatBlock {
  final String content;

  /// true = 仍在流式输出；false = 该 block 已结束
  final bool isStreaming;

  const ClawContentBlock({this.content = '', this.isStreaming = true});

  ClawContentBlock copyWith({String? content, bool? isStreaming}) =>
      ClawContentBlock(
        content: content ?? this.content,
        isStreaming: isStreaming ?? this.isStreaming,
      );

  ClawContentBlock appendChunk(String chunk) =>
      copyWith(content: content + chunk);

  ClawContentBlock finalize() => copyWith(isStreaming: false);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'content',
        'content': content,
      };
}

// ─── Tool call block ──────────────────────────────────────────────────────────

/// 一次工具调用（pending → running → success/error 状态变化时原地更新）
class ClawToolCallBlock extends ClawChatBlock {
  final ClawToolCallRecord record;

  const ClawToolCallBlock({required this.record});

  ClawToolCallBlock copyWith({ClawToolCallRecord? record}) =>
      ClawToolCallBlock(record: record ?? this.record);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'tool_call',
        'record': record.toJson(),
      };
}

// ─── Block type enum（用于 NewBlockEvent）────────────────────────────────────

enum ClawChatBlockType { reasoning, content }
