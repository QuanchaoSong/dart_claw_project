/// 支持的 AI 服务提供商
enum AIProvider {
  openai('OpenAI', 'https://api.openai.com/v1'),
  anthropic('Anthropic', 'https://api.anthropic.com'),
  gemini('Google Gemini', 'https://generativelanguage.googleapis.com/v1beta'),
  deepseek('DeepSeek', 'https://api.deepseek.com/v1'),
  kimi('Kimi', 'https://api.moonshot.cn/v1'),
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

/// 各模型的上下文窗口大小（token 数），用于压缩触发阈值计算
const Map<String, int> kModelContextWindows = {
  // OpenAI
  'gpt-4o': 128000,
  'gpt-4o-mini': 128000,
  'gpt-4-turbo': 128000,
  'gpt-3.5-turbo': 16000,
  // Anthropic
  'claude-opus-4-6': 200000,
  'claude-sonnet-4-5': 200000,
  'claude-haiku-3-5': 200000,
  // Google Gemini
  'gemini-2.0-flash': 1000000,
  'gemini-1.5-pro': 2000000,
  'gemini-1.5-flash': 1000000,
  // DeepSeek
  'deepseek-chat': 64000,
  'deepseek-reasoner': 64000,
  // Kimi
  'kimi-k2.5': 128000,
  'kimi-k2-thinking': 128000,
};

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
  AIProvider.kimi: ['kimi-k2.5', 'kimi-k2-thinking'],
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

  /// 当前模型的上下文窗口大小（token），未知模型返回保守默认值 32000
  int get contextWindow => kModelContextWindows[modelId] ?? 32000;

  /// 压缩触发阈值 = contextWindow × 0.65
  int get compressionThreshold => (contextWindow * 0.65).round();

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
