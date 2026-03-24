/// 服务器相关全局设置（与 session / ai_models 平级，存入 config.json）
class ServerSettingsInfo {
  final int port;

  /// 连接模式：'direct'（同一 WiFi）或 'relay'（中继，暂未实现）
  final String connectionMode;

  /// 是否在启动时自动开启服务器
  final bool isEnabled;

  /// 手机端上传文件的保存目录（支持 ~/... 展开）
  final String uploadSaveDir;

  const ServerSettingsInfo({
    this.port = 37788,
    this.connectionMode = 'direct',
    this.isEnabled = true,
    this.uploadSaveDir = '~/Downloads',
  });

  ServerSettingsInfo copyWith({
    int? port,
    String? connectionMode,
    bool? isEnabled,
    String? uploadSaveDir,
  }) {
    return ServerSettingsInfo(
      port: port ?? this.port,
      connectionMode: connectionMode ?? this.connectionMode,
      isEnabled: isEnabled ?? this.isEnabled,
      uploadSaveDir: uploadSaveDir ?? this.uploadSaveDir,
    );
  }

  factory ServerSettingsInfo.fromJson(Map<String, dynamic> json) {
    final p = json['port'];
    final port =
        (p is int && p > 1024 && p <= 65535) ? p : 37788;
    final mode = json['connection_mode'] as String? ?? 'direct';
    return ServerSettingsInfo(
      port: port,
      connectionMode: mode == 'relay' ? 'relay' : 'direct',
      isEnabled: json['is_enabled'] as bool? ?? true,
      uploadSaveDir: json['upload_save_dir'] as String? ?? '~/Downloads',
    );
  }

  Map<String, dynamic> toJson() => {
        'port': port,
        'connection_mode': connectionMode,
        'is_enabled': isEnabled,
        'upload_save_dir': uploadSaveDir,
      };
}

