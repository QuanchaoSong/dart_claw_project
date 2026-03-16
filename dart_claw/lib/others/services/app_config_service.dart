import 'dart:convert';
import 'dart:io';

import 'package:darted_claw/others/model/ai_model_settings_info.dart';
import 'package:darted_claw/others/model/app_config_info.dart';
import 'package:darted_claw/others/model/session_settings_info.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

// sk-b5e19747344f4ab1a66c08b655c948ca

/// 全局配置服务（GetxService 单例）
/// 负责读写 ~/.darted_claw/config.json
///
/// 使用方式：
///   await Get.putAsync(() => AppConfigService().init());
///
/// 任意位置访问：
///   AppConfigService.to.config
///   AppConfigService.to.saveModelSettings(newInfo)
class AppConfigService extends GetxService {
  static AppConfigService get shared => Get.find<AppConfigService>();

  // 配置目录：~/.darted_claw/
  static String get configDir =>
      p.join(Platform.environment['HOME'] ?? '', '.darted_claw');

  static String get configFilePath => p.join(configDir, 'config.json');

  // 响应式配置对象，UI 层可用 Obx 监听
  final config = AppConfigInfo().obs;

  // ─── 初始化 ─────────────────────────────────────────────────────────────

  Future<AppConfigService> init() async {
    ensureConfigFilePathExists();
    await _loadSettings();
    return this;
  }

  void ensureConfigFilePathExists() {
    final dir = Directory(configDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File(configFilePath);
    if (!file.existsSync()) {
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(AppConfigInfo().toJson()),
      );
    }
  }

  // ─── 读取 ────────────────────────────────────────────────────────────────

  Future<void> _loadSettings() async {
    final file = File(configFilePath);
    if (!await file.exists()) {
      // 首次运行，写入默认配置
      await _writeSettings(AppConfigInfo());
      return;
    }
    try {
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      config.value = AppConfigInfo.fromJson(json);
    } catch (e) {
      // 解析失败时使用默认值，并重置文件
      config.value = AppConfigInfo();
      await _writeSettings(AppConfigInfo());
    }
  }

  // ─── 写入 ────────────────────────────────────────────────────────────────

  Future<void> _writeSettings(AppConfigInfo cfg) async {
    final dir = Directory(configDir);
    if (!await dir.exists()) await dir.create(recursive: true);
    await File(
      configFilePath,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(cfg.toJson()));
  }

  // ─── 公开保存方法 ──────────────────────────────────────────────────────

  Future<void> saveModelSettings(AIModelSettingsInfo model) async {
    config.value = config.value.copyWith(model: model);
    await _writeSettings(config.value);
  }

  Future<void> saveSessionSettings(SessionSettingsInfo session) async {
    config.value = config.value.copyWith(session: session);
    await _writeSettings(config.value);
  }

  Future<void> resetToDefaults() async {
    config.value = AppConfigInfo();
    await _writeSettings(config.value);
  }
}
