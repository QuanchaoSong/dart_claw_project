/// LLM 通过 ask_user 工具发起的用户输入请求（移动端轻量映射）
class AskUserInfo {
  const AskUserInfo({
    required this.id,
    required this.question,
    required this.type,
    this.options = const [],
    this.hint,
  });

  /// 请求唯一 ID，回复时原样附上
  final String id;

  /// 向用户展示的问题
  final String question;

  /// 'text' | 'choice' | 'number'
  final String type;

  /// 选项列表（type == 'choice' 时有意义）
  final List<String> options;

  /// 输入提示占位符（可选）
  final String? hint;
}
