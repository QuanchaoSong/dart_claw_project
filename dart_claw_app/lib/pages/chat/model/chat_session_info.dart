class ChatSessionInfo {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatSessionInfo({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  ChatSessionInfo copyWith({String? title, DateTime? updatedAt}) =>
      ChatSessionInfo(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory ChatSessionInfo.fromMap(Map<String, dynamic> m) => ChatSessionInfo(
        id: m['id'] as String,
        title: m['title'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };
}
