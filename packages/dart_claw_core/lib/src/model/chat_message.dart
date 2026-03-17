import 'chat_block.dart';
import 'tool_call_record.dart';

/// 消息角色
enum ClawChatMessageRole { user, assistant, system }

/// 消息状态
enum ClawChatMessageStatus {
  /// 用户消息已发出，等待 LLM 响应
  sending,

  /// LLM 正在流式输出
  streaming,

  /// 消息已完成（LLM 输出结束 / 工具执行完毕）
  done,

  /// 出现错误
  error,
}

/// 聊天消息数据模型
///
/// assistant 消息由 [blocks] 有序列表组成，每轮 LLM 调用可追加新的
/// reasoning / content / toolCall block，而不会覆盖旧内容。
class ClawChatMessage {
  final String id;
  final ClawChatMessageRole role;
  final DateTime timestamp;
  final ClawChatMessageStatus status;

  /// 有序 block 列表，代表本条消息的完整输出历史
  final List<ClawChatBlock> blocks;

  const ClawChatMessage({
    required this.id,
    required this.role,
    required this.timestamp,
    this.status = ClawChatMessageStatus.done,
    this.blocks = const [],
  });

  // ─── Computed getters (用于 API 序列化 & 兼容旧调用) ──────────────────────

  /// 所有 content block 的文本拼接（用于 toApiJson / 旧代码兼容）
  String get content => blocks
      .whereType<ClawContentBlock>()
      .map((b) => b.content)
      .join('');

  /// 所有 reasoning block 的文本拼接（用于 toApiJson）
  String get reasoningContent => blocks
      .whereType<ClawReasoningBlock>()
      .map((b) => b.content)
      .join('');

  /// 当前所有工具调用记录
  List<ClawToolCallRecord> get toolCalls => blocks
      .whereType<ClawToolCallBlock>()
      .map((b) => b.record)
      .toList();

  // ─── Factory constructors ─────────────────────────────────────────────────

  /// 创建一条用户消息
  factory ClawChatMessage.user(String content) => ClawChatMessage(
        id: _uuid(),
        role: ClawChatMessageRole.user,
        timestamp: DateTime.now(),
        status: ClawChatMessageStatus.done,
        blocks: [ClawContentBlock(content: content, isStreaming: false)],
      );

  /// 创建一条空的 assistant 占位消息（流式输出开始时使用）
  factory ClawChatMessage.assistantStreaming() => ClawChatMessage(
        id: _uuid(),
        role: ClawChatMessageRole.assistant,
        timestamp: DateTime.now(),
        status: ClawChatMessageStatus.streaming,
        blocks: const [],
      );

  // ─── Mutation helpers (均返回新实例，保持不可变) ──────────────────────────

  ClawChatMessage copyWith({
    ClawChatMessageStatus? status,
    List<ClawChatBlock>? blocks,
  }) =>
      ClawChatMessage(
        id: id,
        role: role,
        timestamp: timestamp,
        status: status ?? this.status,
        blocks: blocks ?? this.blocks,
      );

  /// 向末尾追加一个新 block
  ClawChatMessage addBlock(ClawChatBlock block) =>
      copyWith(blocks: [...blocks, block]);

  /// 向最后一个 [ClawContentBlock] 追加流式文本片段
  ClawChatMessage appendChunk(String chunk) {
    final newBlocks = List<ClawChatBlock>.from(blocks);
    final lastIdx = newBlocks.lastIndexWhere((b) => b is ClawContentBlock);
    if (lastIdx == -1) return this;
    newBlocks[lastIdx] =
        (newBlocks[lastIdx] as ClawContentBlock).appendChunk(chunk);
    return copyWith(
        blocks: newBlocks, status: ClawChatMessageStatus.streaming);
  }

  /// 向最后一个 [ClawReasoningBlock] 追加流式推理片段
  ClawChatMessage appendReasoningChunk(String chunk) {
    final newBlocks = List<ClawChatBlock>.from(blocks);
    final lastIdx = newBlocks.lastIndexWhere((b) => b is ClawReasoningBlock);
    if (lastIdx == -1) return this;
    newBlocks[lastIdx] =
        (newBlocks[lastIdx] as ClawReasoningBlock).appendChunk(chunk);
    return copyWith(
        blocks: newBlocks, status: ClawChatMessageStatus.streaming);
  }

  /// 新增或更新一个工具调用 block（通过 record.id 匹配）
  ClawChatMessage updateToolBlock(ClawToolCallRecord record) {
    final newBlocks = List<ClawChatBlock>.from(blocks);
    final idx = newBlocks.indexWhere(
        (b) => b is ClawToolCallBlock && b.record.id == record.id);
    if (idx == -1) {
      newBlocks.add(ClawToolCallBlock(record: record));
    } else {
      newBlocks[idx] = ClawToolCallBlock(record: record);
    }
    return copyWith(blocks: newBlocks);
  }

  /// 标记所有流式 block 结束，消息状态改为 done
  ClawChatMessage finalize() {
    final newBlocks = blocks.map((b) => switch (b) {
          ClawReasoningBlock() => b.finalize(),
          ClawContentBlock() => b.finalize(),
          ClawToolCallBlock() => b,
        }).toList();
    return copyWith(blocks: newBlocks, status: ClawChatMessageStatus.done);
  }

  /// 转为 LLM API 所需的 messages 格式（OpenAI 兼容）
  Map<String, dynamic> toApiJson() {
    final contentStr = content;
    final base = <String, dynamic>{'role': role.name};
    if (contentStr.isNotEmpty) base['content'] = contentStr;

    final reasoning = reasoningContent;
    if (reasoning.isNotEmpty) base['reasoning_content'] = reasoning;

    final tc = toolCalls;
    if (tc.isNotEmpty) {
      base['tool_calls'] = tc.map((t) => t.toApiJson()).toList();
    }

    return base;
  }
}

/// 简易 ID 生成（无外部依赖）
String _uuid() {
  final now = DateTime.now().microsecondsSinceEpoch;
  final rand = now ^ (now >> 16);
  return rand.toRadixString(36);
}

