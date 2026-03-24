import 'dart:io';

import '../model/tool_result.dart';
import 'claw_tool.dart';

/// 让 LLM 将本地文件以可下载卡片的形式推送到手机端聊天界面。
///
/// 调用后桌面端会通过 WS 广播 file_info 事件，手机端渲染
/// FileInfoView（含文件名、大小、弧形进度下载按钮）。
class ShowFileTool implements ClawTool {
  static String _expandHome(String path) {
    if (!path.startsWith('~')) return path;
    final home = Platform.environment['HOME'] ?? '';
    return home + path.substring(1);
  }

  @override
  String get name => 'show_file';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Present a local file to the user as a downloadable card in the chat '
              'interface. Use this when the user asks to access, view, or download a '
              'file from the local machine — especially when they are on a mobile '
              'device and cannot open the file directly. '
              'Accepts absolute local paths (~/... is supported). '
              'The file will appear with its name, size, and a download button.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description':
                    'Absolute local path to the file. ~/... is expanded to the '
                    'home directory. Example: ~/Documents/report.pdf',
              },
              'description': {
                'type': 'string',
                'description':
                    'Optional one-line description shown below the filename '
                    '(e.g. "Found in ~/Documents, last modified today").',
              },
            },
            'required': ['path'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final rawPath = args['path'] as String? ?? '';
    if (rawPath.isEmpty) {
      return ToolResult.failure('path is required');
    }
    final path = _expandHome(rawPath);
    final file = File(path);
    if (!await file.exists()) {
      return ToolResult.failure('File not found: $rawPath');
    }
    final size = await file.length();
    final name = file.uri.pathSegments.last;
    return ToolResult.success(
        'File "$name" ($size bytes) is now shown to the user as a downloadable card.');
  }
}
