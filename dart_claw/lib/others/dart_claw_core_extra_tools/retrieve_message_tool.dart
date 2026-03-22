import 'package:dart_claw/others/tool/database_tool.dart';
import 'package:dart_claw_core/dart_claw_core.dart';

/// 允许 LLM 根据消息 ID 从数据库中检索已归档的历史消息内容。
///
/// 在上下文压缩后，摘要中会嵌入 [ref:msgId] 标记，LLM 可主动调用此工具
/// 取回原始消息的完整内容，用于需要精确细节的场景。
class RetrieveMessageTool implements ClawTool {
  const RetrieveMessageTool();

  @override
  String get name => 'retrieve_message';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Retrieve the full content of an archived chat message by its ID. '
              'Use this when a context summary contains a reference like [ref:someId] '
              'and you need the original message details to answer accurately.',
          'parameters': {
            'type': 'object',
            'properties': {
              'message_id': {
                'type': 'string',
                'description': 'The message ID to retrieve (from a [ref:...] marker in the summary).',
              },
            },
            'required': ['message_id'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final id = args['message_id'] as String?;
    if (id == null || id.trim().isEmpty) {
      return ToolResult.failure('message_id is required.');
    }

    final msg = await DatabaseTool.shared.loadMessageById(id.trim());
    if (msg == null) {
      return ToolResult.failure('No message found with id "$id".');
    }

    final role = msg.role.name;
    final content = msg.content.trim();
    if (content.isEmpty) {
      return ToolResult.success('[$role message $id has no text content]');
    }

    return ToolResult.success('[$role] $content');
  }
}
