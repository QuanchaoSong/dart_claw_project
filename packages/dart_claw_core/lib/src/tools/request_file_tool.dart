/// AI 主动向手机用户请求一个文件。
///
/// 调用时桌面端向移动端发送 `request_file` WS 事件，
/// 移动端弹出文件选择器，用户选择后上传，桌面端接收后 tool 返回本地保存路径。
library;

import '../model/tool_result.dart';
import 'claw_tool.dart';

class RequestFileTool implements ClawTool {
  /// 回调：广播给手机端并等待文件上传完成，返回桌面端保存路径；用户取消或超时返回 null。
  final Future<String?> Function(String prompt) onRequest;

  RequestFileTool({required this.onRequest});

  @override
  String get name => 'request_file';

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Ask the mobile user to select and upload a file from their phone. '
              'Use this when you need a file that exists on the user\'s mobile '
              'device. The user will be shown a file picker. The tool returns '
              'the local path where the file was saved on the desktop.',
          'parameters': {
            'type': 'object',
            'properties': {
              'prompt': {
                'type': 'string',
                'description':
                    'Message shown to the user explaining what file you need.',
              },
            },
            'required': ['prompt'],
          },
        },
      };

  @override
  bool get isDangerous => false;

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final prompt = args['prompt'] as String? ?? '请选择一个文件上传';
    final savedPath = await onRequest(prompt);
    if (savedPath == null || savedPath.isEmpty) {
      return ToolResult.success('用户取消了文件选择，未收到任何文件。');
    }
    return ToolResult.success('文件已收到，桌面端保存路径：$savedPath');
  }
}
