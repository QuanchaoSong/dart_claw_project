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
/// 同时兼容：
/// - 普通对话消息（user / assistant）
/// - 含工具调用的 assistant 消息（[toolCalls] 非空）
class ClawChatMessage {
  final String id;
  final ClawChatMessageRole role;
  final DateTime timestamp;
  final ClawChatMessageStatus status;

  /// 消息正文（流式时逐步追加，assistant tool_call 消息可为空字符串）
  final String content;

  /// LLM 的推理过程（DeepSeek Reasoner 等模型的 reasoning_content，与正文分离存储）
  /// 空字符串表示无推理过程
  final String reasoningContent;

  /// LLM 返回的工具调用列表（仅 role == assistant 时可能非空）
  final List<ClawToolCallRecord> toolCalls;

  const ClawChatMessage({
    required this.id,
    required this.role,
    required this.timestamp,
    this.status = ClawChatMessageStatus.done,
    this.content = '',
    this.reasoningContent = '',
    this.toolCalls = const [],
  });

  /// 创建一条用户消息
  factory ClawChatMessage.user(String content) => ClawChatMessage(
    id: _uuid(),
    role: ClawChatMessageRole.user,
    timestamp: DateTime.now(),
    status: ClawChatMessageStatus.sending,
    content: content,
  );

  /// 创建一条空的 assistant 占位消息（流式输出开始时使用）
  factory ClawChatMessage.assistantStreaming() => ClawChatMessage(
    id: _uuid(),
    role: ClawChatMessageRole.assistant,
    timestamp: DateTime.now(),
    status: ClawChatMessageStatus.streaming,
  );

  ClawChatMessage copyWith({
    String? content,
    String? reasoningContent,
    ClawChatMessageStatus? status,
    List<ClawToolCallRecord>? toolCalls,
  }) {
    return ClawChatMessage(
      id: id,
      role: role,
      timestamp: timestamp,
      status: status ?? this.status,
      content: content ?? this.content,
      reasoningContent: reasoningContent ?? this.reasoningContent,
      toolCalls: toolCalls ?? this.toolCalls,
    );
  }

  /// 追加流式文本片段，返回新实例
  ClawChatMessage appendChunk(String chunk) {
    return copyWith(content: content + chunk, status: ClawChatMessageStatus.streaming);
  }

  /// 追加推理过程片段，返回新实例
  ClawChatMessage appendReasoningChunk(String chunk) {
    return copyWith(
      reasoningContent: reasoningContent + chunk,
      status: ClawChatMessageStatus.streaming,
    );
  }

  /// 标记流式输出完成
  ClawChatMessage finalize() => copyWith(status: ClawChatMessageStatus.done);

  /// 转为 LLM API 所需的 messages 格式（OpenAI 兼容）
  Map<String, dynamic> toApiJson() {
    final base = <String, dynamic>{
      'role': role.name,  // .name 输出 'user'/'assistant'/'system'，与 API 格式一致
      'content': content.isEmpty ? null : content,
    };
    if (toolCalls.isNotEmpty) {
      base['tool_calls'] = toolCalls.map((t) => t.toApiJson()).toList();
    }
    // content 为 null 时移除（纯工具调用消息）
    if (base['content'] == null) base.remove('content');
    return base;
  }
}

/// 简易 ID 生成（无外部依赖）
String _uuid() {
  final now = DateTime.now().microsecondsSinceEpoch;
  final rand = now ^ (now >> 16);
  return rand.toRadixString(36);
}
