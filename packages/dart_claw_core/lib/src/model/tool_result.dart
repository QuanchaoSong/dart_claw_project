/// 工具执行结果
///
/// 统一封装 isSuccess、output、exitCode，供 Agent loop 做失败拦截判断。
/// [visionImagePath] 非 null 时，Runner 会在下一轮 LLM 调用前读取该文件、
/// 编码为 base64，并以 user vision 消息注入 apiMessages。
class ToolResult {
  final bool isSuccess;

  /// 工具输出的完整文本（传给 LLM 的 tool role content）
  final String output;

  /// Shell 类工具的退出码（非 Shell 工具为 null）
  final int? exitCode;

  /// 需要视觉注入的图片路径。非 null 时 Runner 会按需读取并注入 vision 消息。
  final String? visionImagePath;

  const ToolResult({
    required this.isSuccess,
    required this.output,
    this.exitCode,
    this.visionImagePath,
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

  factory ToolResult.vision({
    required String output,
    required String imagePath,
  }) => ToolResult(
        isSuccess: true,
        output: output,
        visionImagePath: imagePath,
      );
}
