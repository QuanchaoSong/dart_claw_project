import '../model/tool_result.dart';
import 'claw_tool.dart';

// ──────────────────────────────────────────────────────────────────────────────
// ask_user
// ──────────────────────────────────────────────────────────────────────────────

/// LLM 征求用户输入的类型。
enum AskUserType {
  /// 自由文本输入（默认）
  text,

  /// 从给定选项中单选
  choice,

  /// 数字输入（键盘限制为数值）
  number,
}

/// LLM 发起的用户输入请求，传给 UI 层回调。
class AskUserRequest {
  const AskUserRequest({
    required this.question,
    this.type = AskUserType.text,
    this.options = const [],
    this.hint,
  });

  /// 向用户展示的问题或说明文字
  final String question;

  /// 输入类型
  final AskUserType type;

  /// 可选项列表（仅 [type] == [AskUserType.choice] 时有意义）
  final List<String> options;

  /// 输入框的占位提示（可选）
  final String? hint;
}

/// 允许 LLM 在 Agent loop 中主动暂停，向用户提问并等待回复。
///
/// 构造时传入 [onAskUser] 回调，由 UI 层弹出对话框收集用户输入并返回。
/// 返回 null 表示用户取消，工具会以 failure 告知 LLM。
class AskUserTool implements ClawTool {
  const AskUserTool({required this.onAskUser});

  /// UI 层实现：展示对话框，返回用户输入；取消时返回 null。
  final Future<String?> Function(AskUserRequest request) onAskUser;

  @override
  String get name => 'ask_user';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Ask the user a question and wait for their input before continuing. '
              'Use this when the task is ambiguous or requires a decision from the user—'
              'for example: choosing between options, supplying a specific value, '
              'or confirming a detail that cannot be inferred from context. '
              'Do NOT use this for simple clarifications you can resolve by reasoning.',
          'parameters': {
            'type': 'object',
            'properties': {
              'question': {
                'type': 'string',
                'description': 'The question or prompt to show the user.',
              },
              'type': {
                'type': 'string',
                'enum': ['text', 'choice', 'number'],
                'description':
                    '"text" (default) — free-form text input. '
                    '"choice" — user picks one item from the "options" list. '
                    '"number" — user enters a numeric value.',
              },
              'options': {
                'type': 'array',
                'items': {'type': 'string'},
                'description':
                    'Required when type is "choice". The list of options the user can pick from.',
              },
              'hint': {
                'type': 'string',
                'description':
                    'Optional placeholder or example shown inside the input field.',
              },
            },
            'required': ['question'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final question = args['question'] as String? ?? '';
    final typeStr = args['type'] as String? ?? 'text';
    final type = switch (typeStr) {
      'choice' => AskUserType.choice,
      'number' => AskUserType.number,
      _ => AskUserType.text,
    };
    final options = (args['options'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final hint = args['hint'] as String?;

    final request = AskUserRequest(
      question: question,
      type: type,
      options: options,
      hint: hint,
    );

    final response = await onAskUser(request);
    if (response == null) {
      return ToolResult.failure(
        'User cancelled the input. Do not retry — ask the user what they would '
        'like to do instead.',
      );
    }
    return ToolResult.success('User responded: $response');
  }
}
