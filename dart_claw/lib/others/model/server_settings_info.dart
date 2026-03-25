import 'dart:math';

/// 服务器相关全局设置（与 session / ai_models 平级，存入 config.json）
class ServerSettingsInfo {
  final int port;

  /// 连接模式：'direct'（同一 WiFi）或 'relay'（中继，暂未实现）
  final String connectionMode;

  /// 是否在启动时自动开启服务器
  final bool isEnabled;

  /// 手机端上传文件的保存目录（支持 ~/... 展开）
  final String uploadSaveDir;

  /// WebSocket 连接安全码（客户端连接时需携带 ?code=XXX）
  final String securityCode;

  /// 安全码长度（8 / 16 / 32），切换时自动重新生成
  final int securityCodeLength;

  const ServerSettingsInfo({
    this.port = 37788,
    this.connectionMode = 'direct',
    this.isEnabled = true,
    this.uploadSaveDir = '~/Downloads',
    this.securityCode = '',
    this.securityCodeLength = 8,
  });

  ServerSettingsInfo copyWith({
    int? port,
    String? connectionMode,
    bool? isEnabled,
    String? uploadSaveDir,
    String? securityCode,
    int? securityCodeLength,
  }) {
    return ServerSettingsInfo(
      port: port ?? this.port,
      connectionMode: connectionMode ?? this.connectionMode,
      isEnabled: isEnabled ?? this.isEnabled,
      uploadSaveDir: uploadSaveDir ?? this.uploadSaveDir,
      securityCode: securityCode ?? this.securityCode,
      securityCodeLength: securityCodeLength ?? this.securityCodeLength,
    );
  }

  factory ServerSettingsInfo.fromJson(Map<String, dynamic> json) {
    final p = json['port'];
    final port =
        (p is int && p > 1024 && p <= 65535) ? p : 37788;
    final mode = json['connection_mode'] as String? ?? 'direct';
    final codeLen = json['security_code_length'] as int? ?? 8;
    final validLen = const [8, 16, 32].contains(codeLen) ? codeLen : 8;
    var code = json['security_code'] as String? ?? '';
    if (code.isEmpty) code = _generateCode(validLen);
    return ServerSettingsInfo(
      port: port,
      connectionMode: mode == 'relay' ? 'relay' : 'direct',
      isEnabled: json['is_enabled'] as bool? ?? true,
      uploadSaveDir: json['upload_save_dir'] as String? ?? '~/Downloads',
      securityCode: code,
      securityCodeLength: validLen,
    );
  }

  Map<String, dynamic> toJson() => {
        'port': port,
        'connection_mode': connectionMode,
        'is_enabled': isEnabled,
        'upload_save_dir': uploadSaveDir,
        'security_code': securityCode,
        'security_code_length': securityCodeLength,
      };

  /// 生成随机安全码（大小写字母 + 数字）
  static String generateCode(int length) => _generateCode(length);

  static String _generateCode(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)])
        .join();
  }
}

