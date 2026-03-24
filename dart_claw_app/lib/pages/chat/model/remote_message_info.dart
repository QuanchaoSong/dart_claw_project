import 'dart:convert';

/// 移动端消息模型（不依赖 dart_claw_core）。
enum RemoteMessageInfoType { user, assistant, tool, confirm, log }

class RemoteMessageInfo {
  final String id;
  final RemoteMessageInfoType type;

  /// 主文本：assistant 为流式输出，confirm 为提示文本，log 为日志
  String content;

  /// 推理过程文本（reasoning_chunk 累积，assistant 类型专用）
  String reasoning = '';

  /// 工具名（tool 类型专用）
  String? toolName;

  /// 工具调用 ID（用于匹配状态更新）
  String? toolId;

  /// 工具状态：pending / running / success / error / awaitingConfirmation
  String toolStatus;

  /// 工具调用的原始 args（tool 类型专用，持久化为 JSON）。
  /// show_image / show_video / show_chart 等多媒体数据均从此派生。
  Map<String, dynamic>? toolArgs;

  // ── 从 toolArgs 派生的便捷 getters ──────────────────────────────────────

  List<String> get imagePaths {
    if (toolName != 'show_image') return const [];
    final p = toolArgs?['paths'];
    return p is List ? p.cast<String>() : const [];
  }

  String? get videoUrl {
    if (toolName != 'show_video') return null;
    final p = toolArgs?['path'];
    return p is String && p.isNotEmpty ? p : null;
  }

  Map<String, dynamic>? get chartData {
    if (toolName != 'show_chart') return null;
    return toolArgs;
  }

  /// 确认请求 ID（confirm 类型专用）
  String? confirmId;

  /// assistant 是否仍在流式输出中
  bool isStreaming;

  RemoteMessageInfo._({
    required this.id,
    required this.type,
    this.content = '',
    this.toolName,
    this.toolId,
    this.toolStatus = 'running',
    this.toolArgs,
    this.confirmId,
    this.isStreaming = false,
  });

  static String _newId() {
    final t = DateTime.now().microsecondsSinceEpoch;
    return (t ^ (t >> 16)).toRadixString(36);
  }

  factory RemoteMessageInfo.user(String content) => RemoteMessageInfo._(
        id: _newId(),
        type: RemoteMessageInfoType.user,
        content: content,
      );

  factory RemoteMessageInfo.assistantStreaming() => RemoteMessageInfo._(
        id: _newId(),
        type: RemoteMessageInfoType.assistant,
        isStreaming: true,
      );

  factory RemoteMessageInfo.tool({
    required String toolId,
    required String toolName,
    required String toolStatus,
    Map<String, dynamic>? args,
  }) =>
      RemoteMessageInfo._(
        id: _newId(),
        type: RemoteMessageInfoType.tool,
        toolId: toolId,
        toolName: toolName,
        toolStatus: toolStatus,
        content: _argsPreview(args),
        toolArgs: args,
      );

  factory RemoteMessageInfo.confirm({
    required String confirmId,
    required String message,
  }) =>
      RemoteMessageInfo._(
        id: _newId(),
        type: RemoteMessageInfoType.confirm,
        content: message,
        confirmId: confirmId,
      );

  factory RemoteMessageInfo.log(String content) => RemoteMessageInfo._(
        id: _newId(),
        type: RemoteMessageInfoType.log,
        content: content,
      );

  /// 取第一个参数值的前 60 字作为工具卡片副标题
  static String _argsPreview(Map<String, dynamic>? args) {
    if (args == null || args.isEmpty) return '';
    final val = args.entries.first.value.toString();
    return val.length > 60 ? '${val.substring(0, 60)}…' : val;
  }

  /// 从 SQLite 行恢复（保留存储的 id）
  factory RemoteMessageInfo.fromMap(Map<String, dynamic> m) {
    final type = RemoteMessageInfoType.values.byName(m['type'] as String);
    final rawArgs = m['tool_args'] as String?;
    final info = RemoteMessageInfo._(
      id: m['id'] as String,
      type: type,
      content: m['content'] as String? ?? '',
      toolName: m['tool_name'] as String?,
      toolId: m['tool_id'] as String?,
      toolStatus: m['tool_status'] as String? ?? 'success',
      toolArgs: rawArgs != null
          ? jsonDecode(rawArgs) as Map<String, dynamic>
          : null,
      isStreaming: false,
    );
    info.reasoning = m['reasoning'] as String? ?? '';
    return info;
  }
}

