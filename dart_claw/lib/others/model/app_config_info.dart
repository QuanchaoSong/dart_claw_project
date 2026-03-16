import 'package:darted_claw/others/model/ai_model_settings_info.dart';
import 'package:darted_claw/others/model/session_settings_info.dart';

/// 顶层 App 配置（聚合所有 settings）
class AppConfigInfo {
  final AIModelSettingsInfo model;
  final SessionSettingsInfo session;

  const AppConfigInfo({
    this.model = const AIModelSettingsInfo(),
    this.session = const SessionSettingsInfo(),
  });

  AppConfigInfo copyWith({
    AIModelSettingsInfo? model,
    SessionSettingsInfo? session,
  }) {
    return AppConfigInfo(
      model: model ?? this.model,
      session: session ?? this.session,
    );
  }

  factory AppConfigInfo.fromJson(Map<String, dynamic> json) {
    return AppConfigInfo(
      model: AIModelSettingsInfo.fromJson(
        json['model'] as Map<String, dynamic>? ?? {},
      ),
      session: SessionSettingsInfo.fromJson(
        json['session'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'model': model.toJson(),
    'session': session.toJson(),
  };
}
