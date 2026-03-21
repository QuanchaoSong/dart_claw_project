/// 会话设置
class SessionSettingsInfo {
  final bool autoSave;
  final int maxHistoryCount; // 保留最近 N 条会话
  final int maxRounds;       // Agent 最大工具调用轮次
  final bool browserRememberLogin; // 浏览器是否跨重启保留登录状态
  final bool askUserUseDialog; // Agent 提问时使用 Dialog（true）还是内联卡片（false）

  const SessionSettingsInfo({
    this.autoSave = true,
    this.maxHistoryCount = 50,
    this.maxRounds = 20,
    this.browserRememberLogin = true,
    this.askUserUseDialog = true,
  });

  SessionSettingsInfo copyWith({
    bool? autoSave,
    int? maxHistoryCount,
    int? maxRounds,
    bool? browserRememberLogin,
    bool? askUserUseDialog,
  }) {
    return SessionSettingsInfo(
      autoSave: autoSave ?? this.autoSave,
      maxHistoryCount: maxHistoryCount ?? this.maxHistoryCount,
      maxRounds: maxRounds ?? this.maxRounds,
      browserRememberLogin: browserRememberLogin ?? this.browserRememberLogin,
      askUserUseDialog: askUserUseDialog ?? this.askUserUseDialog,
    );
  }

  factory SessionSettingsInfo.fromJson(Map<String, dynamic> json) {
    return SessionSettingsInfo(
      autoSave: json['autoSave'] as bool? ?? true,
      maxHistoryCount: json['maxHistoryCount'] as int? ?? 50,
      maxRounds: json['maxRounds'] as int? ?? 20,
      browserRememberLogin: json['browserRememberLogin'] as bool? ?? true,
      askUserUseDialog: json['askUserUseDialog'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'autoSave': autoSave,
    'maxHistoryCount': maxHistoryCount,
    'maxRounds': maxRounds,
    'browserRememberLogin': browserRememberLogin,
    'askUserUseDialog': askUserUseDialog,
  };
}
