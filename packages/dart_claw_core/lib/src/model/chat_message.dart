import 'chat_block.dart';
import 'tool_call_record.dart';

/// 消息角色
enum ClawChatMessageRole { user, assistant, system }

/// 消息类型（用于区分普通消息、摘要、UI 分隔行、日志行）
enum ClawChatMessageType { message, summary, divider, log }

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
  final ClawChatMessageType type;

  /// 有序 block 列表，代表本条消息的完整输出历史
  final List<ClawChatBlock> blocks;

  /// 用户消息附带的本地文件路径（仅 user 消息使用）
  final List<String> attachedPaths;

  const ClawChatMessage({
    required this.id,
    required this.role,
    required this.timestamp,
    this.status = ClawChatMessageStatus.done,
    this.type = ClawChatMessageType.message,
    this.blocks = const [],
    this.attachedPaths = const [],
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
  factory ClawChatMessage.user(String content,
          {List<String> attachedPaths = const []}) =>
      ClawChatMessage(
        id: _uuid(),
        role: ClawChatMessageRole.user,
        timestamp: DateTime.now(),
        status: ClawChatMessageStatus.done,
        blocks: [ClawContentBlock(content: content, isStreaming: false)],
        attachedPaths: attachedPaths,
      );

  /// 创建一条空的 assistant 占位消息（流式输出开始时使用）
  factory ClawChatMessage.assistantStreaming() => ClawChatMessage(
        id: _uuid(),
        role: ClawChatMessageRole.assistant,
        timestamp: DateTime.now(),
        status: ClawChatMessageStatus.streaming,
        blocks: const [],
      );

  /// 创建一条摘要消息（role=system, type=summary，注入上下文但不显示为气泡）
  factory ClawChatMessage.summary(String content) => ClawChatMessage(
        id: _uuid(),
        role: ClawChatMessageRole.system,
        timestamp: DateTime.now(),
        status: ClawChatMessageStatus.done,
        type: ClawChatMessageType.summary,
        blocks: [ClawContentBlock(content: content, isStreaming: false)],
      );

  /// 创建一条 UI 分隔行（type=divider，仅供可视化，不进入 API 上下文）
  factory ClawChatMessage.divider() => ClawChatMessage(
        id: _uuid(),
        role: ClawChatMessageRole.system,
        timestamp: DateTime.now(),
        status: ClawChatMessageStatus.done,
        type: ClawChatMessageType.divider,
        blocks: const [],
      );

  /// 创建一条内联日志行（type=log，仅供可视化，不进入 API 上下文）
  factory ClawChatMessage.log(String content) => ClawChatMessage(
        id: _uuid(),
        role: ClawChatMessageRole.system,
        timestamp: DateTime.now(),
        status: ClawChatMessageStatus.done,
        type: ClawChatMessageType.log,
        blocks: [ClawContentBlock(content: content, isStreaming: false)],
      );

  // ─── Mutation helpers (均返回新实例，保持不可变) ──────────────────────────

  ClawChatMessage copyWith({
    ClawChatMessageStatus? status,
    ClawChatMessageType? type,
    List<ClawChatBlock>? blocks,
    List<String>? attachedPaths,
  }) =>
      ClawChatMessage(
        id: id,
        role: role,
        timestamp: timestamp,
        status: status ?? this.status,
        type: type ?? this.type,
        blocks: blocks ?? this.blocks,
        attachedPaths: attachedPaths ?? this.attachedPaths,
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
  ///
  /// 对于 assistant 消息，始终只返回单条（当前 block 的快照）。
  /// 如果需要完整的多轮序列（含 tool result messages），请用 [toApiMessages]。
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

  /// 将本条消息展开为 API 所需的完整 message 序列。
  ///
  /// - user / system 消息：返回单条
  /// - assistant 消息：按 block 顺序重建多轮结构，每轮 assistant 消息后紧跟工具结果消息
  ///   Example blocks → API sequence:
  ///   [ReasoningBlock, ContentBlock, ToolCallBlock(tc1), ToolCallBlock(tc2),
  ///    ReasoningBlock, ContentBlock]
  ///   →
  ///   {assistant, reasoning, content, tool_calls:[tc1,tc2]}
  ///   {tool, tool_call_id:tc1.id, content:...}
  ///   {tool, tool_call_id:tc2.id, content:...}
  ///   {assistant, reasoning, content}
  List<Map<String, dynamic>> toApiMessages() {
    if (role != ClawChatMessageRole.assistant) return [toApiJson()];

    final result = <Map<String, dynamic>>[];

    String currentContent = '';
    String currentReasoning = '';
    final currentToolCalls = <ClawToolCallRecord>[];
    bool hasContent = false;
    bool inToolPhase = false;

    void flushRound() {
      if (!hasContent) return;
      final msg = <String, dynamic>{'role': 'assistant'};
      if (currentContent.isNotEmpty) msg['content'] = currentContent;
      if (currentReasoning.isNotEmpty) {
        msg['reasoning_content'] = currentReasoning;
      }
      if (currentToolCalls.isNotEmpty) {
        msg['tool_calls'] =
            currentToolCalls.map((t) => t.toApiJson()).toList();
      }
      result.add(msg);
      for (final tc in currentToolCalls) {
        result.add(tc.toResultApiJson());
      }
      currentContent = '';
      currentReasoning = '';
      currentToolCalls.clear();
      hasContent = false;
    }

    for (final block in blocks) {
      switch (block) {
        case ClawReasoningBlock():
          if (inToolPhase) {
            flushRound();
            inToolPhase = false;
          }
          currentReasoning += block.content;
          hasContent = true;
        case ClawContentBlock():
          if (inToolPhase) {
            flushRound();
            inToolPhase = false;
          }
          currentContent += block.content;
          hasContent = true;
        case ClawToolCallBlock():
          inToolPhase = true;
          currentToolCalls.add(block.record);
          hasContent = true;
      }
    }
    flushRound();

    return result;
  }

  // ─── 持久化序列化 ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'status': status.name,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        if (attachedPaths.isNotEmpty) 'attached_paths': attachedPaths,
      };

  factory ClawChatMessage.fromJson(Map<String, dynamic> json) =>
      ClawChatMessage(
        id: json['id'] as String,
        role: ClawChatMessageRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => ClawChatMessageRole.user,
        ),
        timestamp: DateTime.fromMillisecondsSinceEpoch(
            json['timestamp'] as int),
        status: ClawChatMessageStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => ClawChatMessageStatus.done,
        ),
        type: ClawChatMessageType.values.firstWhere(
          (t) => t.name == (json['type'] as String? ?? 'message'),
          orElse: () => ClawChatMessageType.message,
        ),
        blocks: (json['blocks'] as List<dynamic>)
            .map((b) => ClawChatBlock.fromJson(b as Map<String, dynamic>))
            .toList(),
        attachedPaths: (json['attached_paths'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
      );
}

/// 简易 ID 生成（无外部依赖）
String _uuid() {
  final now = DateTime.now().microsecondsSinceEpoch;
  final rand = now ^ (now >> 16);
  return rand.toRadixString(36);
}

