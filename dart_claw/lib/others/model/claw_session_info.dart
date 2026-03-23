class ClawSessionInfo {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 'local' = created on this desktop; 'remote' = initiated from mobile app
  final String source;

  const ClawSessionInfo({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.source = 'local',
  });

  ClawSessionInfo copyWith({String? title, DateTime? updatedAt}) =>
      ClawSessionInfo(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        source: source,
      );

  factory ClawSessionInfo.fromMap(Map<String, dynamic> m) => ClawSessionInfo(
        id: m['id'] as String,
        title: m['title'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
        source: m['source'] as String? ?? 'local',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'source': source,
      };
}
