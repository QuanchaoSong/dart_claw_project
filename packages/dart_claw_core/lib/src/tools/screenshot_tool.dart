import 'dart:io';
import '../model/tool_result.dart';
import 'claw_tool.dart';

/// 截取屏幕（全屏或指定区域），保存为 JPEG，返回图片路径。
///
/// LLM 拿到路径后可直接调 [VisionReadImageTool] 分析图片内容，
/// 然后根据分析结果决定下一步操作（移动鼠标、点击等）。
///
/// 参数（全部可选）：
/// - `x`, `y`, `width`, `height`：截取指定像素区域；全部省略则全屏截图。
/// - `filename`：自定义保存文件名（不含扩展名），省略时自动生成。
class ScreenshotTool implements ClawTool {
  const ScreenshotTool();

  @override
  String get name => 'screenshot';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Capture a screenshot of the screen and return the image file path. '
              'Use this to see the current state of the screen before deciding '
              'where to move the mouse or click. '
              'For large screens or when you already know the approximate area of interest, '
              'supply x/y/width/height to capture only that region and reduce image size. '
              'The image is saved as JPEG. Pass the returned path to vision_read_image '
              'to analyze its contents.',
          'parameters': {
            'type': 'object',
            'properties': {
              'x': {
                'type': 'number',
                'description':
                    'Left edge of the capture region in screen points. '
                    'Omit for full-screen capture.',
              },
              'y': {
                'type': 'number',
                'description':
                    'Top edge of the capture region in screen points. '
                    'Omit for full-screen capture.',
              },
              'width': {
                'type': 'number',
                'description':
                    'Width of the capture region in screen points. '
                    'Omit for full-screen capture.',
              },
              'height': {
                'type': 'number',
                'description':
                    'Height of the capture region in screen points. '
                    'Omit for full-screen capture.',
              },
              'filename': {
                'type': 'string',
                'description':
                    'Optional base name for the saved file (no extension). '
                    'Defaults to a timestamp-based name.',
              },
            },
            'required': [],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final x = args['x'];
    final y = args['y'];
    final width = args['width'];
    final height = args['height'];
    final filename = args['filename'] as String?;

    // ── Output path ───────────────────────────────────────────────────────────
    final tempDir = Directory.systemTemp.path;
    final baseName =
        filename ?? 'screenshot_${DateTime.now().millisecondsSinceEpoch}';
    final outputPath = '$tempDir/$baseName.jpg';

    // ── Build screencapture arguments ─────────────────────────────────────────
    // -x  = no sound
    // -t jpg = JPEG output
    final cmdArgs = <String>['-x', '-t', 'jpg'];

    final hasRegion = x != null && y != null && width != null && height != null;
    if (hasRegion) {
      final rx = (x as num).toInt();
      final ry = (y as num).toInt();
      final rw = (width as num).toInt();
      final rh = (height as num).toInt();
      cmdArgs.addAll(['-R', '$rx,$ry,$rw,$rh']);
    }

    cmdArgs.add(outputPath);

    // ── Execute ───────────────────────────────────────────────────────────────
    final result = await Process.run('screencapture', cmdArgs);

    if (result.exitCode != 0) {
      return ToolResult.failure(
        'screencapture failed (exit ${result.exitCode}): ${result.stderr}',
      );
    }

    if (!File(outputPath).existsSync()) {
      return ToolResult.failure('Screenshot file not found at $outputPath');
    }

    final regionDesc = hasRegion
        ? '(region: x=$x, y=$y, w=$width, h=$height)'
        : '(full screen)';

    return ToolResult.success(
      'Screenshot saved $regionDesc → $outputPath\n'
      'Pass this path to vision_read_image to analyze the contents.',
    );
  }
}
