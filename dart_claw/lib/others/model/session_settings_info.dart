/// 会话设置
class SessionSettingsInfo {
  final bool autoSave;
  final int maxHistoryCount; // 保留最近 N 条会话

  const SessionSettingsInfo({this.autoSave = true, this.maxHistoryCount = 50});

  SessionSettingsInfo copyWith({bool? autoSave, int? maxHistoryCount}) {
    return SessionSettingsInfo(
      autoSave: autoSave ?? this.autoSave,
      maxHistoryCount: maxHistoryCount ?? this.maxHistoryCount,
    );
  }

  factory SessionSettingsInfo.fromJson(Map<String, dynamic> json) {
    return SessionSettingsInfo(
      autoSave: json['autoSave'] as bool? ?? true,
      maxHistoryCount: json['maxHistoryCount'] as int? ?? 50,
    );
  }

  Map<String, dynamic> toJson() => {
    'autoSave': autoSave,
    'maxHistoryCount': maxHistoryCount,
  };
}
