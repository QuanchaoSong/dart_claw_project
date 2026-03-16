/// 工具执行状态
enum ClawToolStatus {
  /// 等待执行（tool_call 已解析，尚未开始）
  pending,

  /// 执行中
  running,

  /// 高危操作，等待用户确认
  awaitingConfirmation,

  /// 执行成功
  success,

  /// 执行失败
  error,
}

/// 一次工具调用的完整记录
class ClawToolCallRecord {
  /// LLM 返回的 tool_call id（用于回填结果到上下文）
  final String id;

  /// 工具名称，如 "read_file"、"run_command"
  final String name;

  /// LLM 传入的参数
  final Map<String, dynamic> args;

  /// 执行结果（成功时为输出内容，失败时为错误信息）
  final String? result;

  /// 当前状态
  final ClawToolStatus status;

  /// 是否属于高危操作（需要用户确认）
  final bool isDangerous;

  const ClawToolCallRecord({
    required this.id,
    required this.name,
    required this.args,
    this.result,
    this.status = ClawToolStatus.pending,
    this.isDangerous = false,
  });

  ClawToolCallRecord copyWith({
    String? result,
    ClawToolStatus? status,
    bool? isDangerous,
  }) {
    return ClawToolCallRecord(
      id: id,
      name: name,
      args: args,
      result: result ?? this.result,
      status: status ?? this.status,
      isDangerous: isDangerous ?? this.isDangerous,
    );
  }

  /// 转为 OpenAI tool_calls 格式（assistant 消息里的 tool_call 项）
  Map<String, dynamic> toApiJson() {
    return {
      'id': id,
      'type': 'function',
      'function': {
        'name': name,
        'arguments': _encodeArgs(args),
      },
    };
  }

  /// 转为 OpenAI tool 角色消息（工具执行结果回填）
  Map<String, dynamic> toResultApiJson() {
    return {
      'role': 'tool',
      'tool_call_id': id,
      'content': result ?? '',
    };
  }
}

String _encodeArgs(Map<String, dynamic> args) {
  // 简单 JSON 序列化，不引入 dart:convert 以外的依赖
  final buf = StringBuffer('{');
  var first = true;
  args.forEach((k, v) {
    if (!first) buf.write(',');
    first = false;
    buf.write('"$k":');
    if (v is String) {
      buf.write('"${v.replaceAll('"', '\\"')}"');
    } else {
      buf.write(v);
    }
  });
  buf.write('}');
  return buf.toString();
}
