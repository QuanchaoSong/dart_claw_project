/// 单个工具的接口
abstract interface class ClawTool {
  /// OpenAI function name（唯一标识，如 "run_command"）
  String get name;

  /// 是否属于高危操作（需要用户确认）
  bool get isDangerous;

  /// OpenAI tools 格式的函数声明（用于传给 LLM）
  Map<String, dynamic> get definition;

  /// 执行工具，返回结果字符串
  ///
  /// [args] 是 LLM 传来的参数 Map（已经过 JSON 解析）
  Future<String> execute(Map<String, dynamic> args);
}
