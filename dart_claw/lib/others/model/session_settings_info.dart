/// 会话设置
class SessionSettingsInfo {
  final bool autoSave;
  final int maxHistoryCount; // 保留最近 N 条会话
  final int maxRounds;       // Agent 最大工具调用轮次

  const SessionSettingsInfo({
    this.autoSave = true,
    this.maxHistoryCount = 50,
    this.maxRounds = 20,
  });

  SessionSettingsInfo copyWith({
    bool? autoSave,
    int? maxHistoryCount,
    int? maxRounds,
  }) {
    return SessionSettingsInfo(
      autoSave: autoSave ?? this.autoSave,
      maxHistoryCount: maxHistoryCount ?? this.maxHistoryCount,
      maxRounds: maxRounds ?? this.maxRounds,
    );
  }

  factory SessionSettingsInfo.fromJson(Map<String, dynamic> json) {
    return SessionSettingsInfo(
      autoSave: json['autoSave'] as bool? ?? true,
      maxHistoryCount: json['maxHistoryCount'] as int? ?? 50,
      maxRounds: json['maxRounds'] as int? ?? 20,
    );
  }

  Map<String, dynamic> toJson() => {
    'autoSave': autoSave,
    'maxHistoryCount': maxHistoryCount,
    'maxRounds': maxRounds,
  };
}
