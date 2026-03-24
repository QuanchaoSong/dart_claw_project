import 'package:dart_claw/others/model/ai_model_settings_info.dart';
import 'package:dart_claw/others/model/server_settings_info.dart';
import 'package:dart_claw/others/model/session_settings_info.dart';

/// 顶层 App 配置（聚合所有 settings）
///
/// 每个 provider 的配置独立保存在 [providerConfigs] 中，
/// 切换 provider 时不会丢失其他 provider 的 apiKey / model 等设置。
class AppConfigInfo {
  final AIProvider activeProvider;

  /// 按 provider 分别保存的配置（provider → 该 provider 的完整配置）
  final Map<AIProvider, AIModelSettingsInfo> providerConfigs;

  final SessionSettingsInfo session;
  final ServerSettingsInfo server;

  const AppConfigInfo({
    this.activeProvider = AIProvider.openai,
    this.providerConfigs = const {},
    this.session = const SessionSettingsInfo(),
    this.server = const ServerSettingsInfo(),
  });

  /// 当前激活的模型配置（供业务层直接使用）
  AIModelSettingsInfo get model =>
      providerConfigs[activeProvider] ??
      AIModelSettingsInfo(provider: activeProvider);

  AppConfigInfo copyWith({
    AIProvider? activeProvider,
    Map<AIProvider, AIModelSettingsInfo>? providerConfigs,
    SessionSettingsInfo? session,
    ServerSettingsInfo? server,
  }) {
    return AppConfigInfo(
      activeProvider: activeProvider ?? this.activeProvider,
      providerConfigs: providerConfigs ?? this.providerConfigs,
      session: session ?? this.session,
      server: server ?? this.server,
    );
  }

  factory AppConfigInfo.fromJson(Map<String, dynamic> json) {
    final Map<AIProvider, AIModelSettingsInfo> configs = {};
    final ai = json['ai_models'] as Map<String, dynamic>? ?? {};
    final active = AIProvider.fromString(
        ai['activeProvider'] as String? ?? 'openai');
    final raw = ai['providerConfigs'] as Map<String, dynamic>? ?? {};
    for (final entry in raw.entries) {
      configs[AIProvider.fromString(entry.key)] =
          AIModelSettingsInfo.fromJson(entry.value as Map<String, dynamic>);
    }
    return AppConfigInfo(
      activeProvider: active,
      providerConfigs: configs,
      session: SessionSettingsInfo.fromJson(
          json['session'] as Map<String, dynamic>? ?? {}),
      server: ServerSettingsInfo.fromJson(
          json['server'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'ai_models': {
          'activeProvider': activeProvider.name,
          'providerConfigs': {
            for (final e in providerConfigs.entries)
              e.key.name: e.value.toJson(),
          },
        },
        'session': session.toJson(),
        'server': server.toJson(),
      };
}
