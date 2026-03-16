import 'package:darted_claw/others/model/session_settings_info.dart';

/// 支持的 AI 服务提供商
enum AIProvider {
  openai('OpenAI', 'https://api.openai.com/v1'),
  anthropic('Anthropic', 'https://api.anthropic.com'),
  gemini('Google Gemini', 'https://generativelanguage.googleapis.com/v1beta'),
  deepseek('DeepSeek', 'https://api.deepseek.com/v1'),
  custom('Custom', '');

  final String displayName;
  final String defaultBaseUrl;
  const AIProvider(this.displayName, this.defaultBaseUrl);

  static AIProvider fromString(String value) {
    return AIProvider.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AIProvider.openai,
    );
  }
}

/// 各 Provider 下的预设模型列表
const Map<AIProvider, List<String>> kProviderModels = {
  AIProvider.openai: ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-3.5-turbo'],
  AIProvider.anthropic: [
    'claude-opus-4-6',
    'claude-sonnet-4-5',
    'claude-haiku-3-5',
  ],
  AIProvider.gemini: ['gemini-2.0-flash', 'gemini-1.5-pro', 'gemini-1.5-flash'],
  AIProvider.deepseek: ['deepseek-chat', 'deepseek-reasoner'],
  AIProvider.custom: [],
};

/// AI 模型配置数据模型
class AIModelSettingsInfo {
  final AIProvider provider;
  final String modelId;
  final String apiKey;
  final double temperature;
  final int maxTokens;
  final String? customBaseUrl; // provider 为 custom 时使用

  const AIModelSettingsInfo({
    this.provider = AIProvider.openai,
    this.modelId = 'gpt-4o',
    this.apiKey = '',
    this.temperature = 0.7,
    this.maxTokens = 4096,
    this.customBaseUrl,
  });

  String get effectiveBaseUrl => provider == AIProvider.custom
      ? (customBaseUrl ?? '')
      : provider.defaultBaseUrl;

  AIModelSettingsInfo copyWith({
    AIProvider? provider,
    String? modelId,
    String? apiKey,
    double? temperature,
    int? maxTokens,
    String? customBaseUrl,
  }) {
    return AIModelSettingsInfo(
      provider: provider ?? this.provider,
      modelId: modelId ?? this.modelId,
      apiKey: apiKey ?? this.apiKey,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      customBaseUrl: customBaseUrl ?? this.customBaseUrl,
    );
  }

  factory AIModelSettingsInfo.fromJson(Map<String, dynamic> json) {
    return AIModelSettingsInfo(
      provider: AIProvider.fromString(json['provider'] as String? ?? 'openai'),
      modelId: json['modelId'] as String? ?? 'gpt-4o',
      apiKey: json['apiKey'] as String? ?? '',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens: json['maxTokens'] as int? ?? 4096,
      customBaseUrl: json['customBaseUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider.name,
    'modelId': modelId,
    'apiKey': apiKey,
    'temperature': temperature,
    'maxTokens': maxTokens,
    if (customBaseUrl != null) 'customBaseUrl': customBaseUrl,
  };
}
