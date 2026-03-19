/// 工具执行结果
///
/// 统一封装 isSuccess、output、exitCode，供 Agent loop 做失败拦截判断。
class ToolResult {
  final bool isSuccess;

  /// 工具输出的完整文本（传给 LLM 的 content）
  final String output;

  /// Shell 类工具的退出码（非 Shell 工具为 null）
  final int? exitCode;

  const ToolResult({
    required this.isSuccess,
    required this.output,
    this.exitCode,
  });

  factory ToolResult.success(String output, {int? exitCode}) => ToolResult(
        isSuccess: true,
        output: output,
        exitCode: exitCode,
      );

  factory ToolResult.failure(String output, {int? exitCode}) => ToolResult(
        isSuccess: false,
        output: output,
        exitCode: exitCode,
      );
}
