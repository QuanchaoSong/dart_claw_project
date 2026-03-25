import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../others/network/http_digger.dart';
import '../../others/services/connection_service.dart';
import '../connection/connection_page.dart';

class SettingsLogic extends GetxController {
  ConnectionService get _conn => ConnectionService();
  final _http = HttpDigger();

  String get serverUrl => _conn.serverUrl;
  bool get isConnected => _conn.isConnected.value;
  bool get isRelayMode => _conn.isRelayMode.value;

  // ── 加载状态 ──
  final isLoading = true.obs;
  final loadError = RxnString();

  // ── AI Model ──
  final provider = ''.obs;
  final providerDisplayName = ''.obs;
  final modelId = ''.obs;
  final temperature = 0.7.obs;
  final maxTokens = 4096.obs;
  final availableProviders = <Map<String, dynamic>>[].obs;
  final availableModels = <String>[].obs;

  // ── Session ──
  final maxRounds = 20.obs;

  // ── Scheduler ──
  final schedulerTasks = <Map<String, dynamic>>[].obs;

  // ── Relay ──
  final relayFileMaxMB = 20.obs; // 默认 20 MB

  // ── Controllers ──
  late final TextEditingController temperatureController;
  late final TextEditingController maxTokensController;
  late final TextEditingController maxRoundsController;

  @override
  void onInit() {
    super.onInit();
    temperatureController = TextEditingController();
    maxTokensController = TextEditingController();
    maxRoundsController = TextEditingController();
    loadAll();
  }

  @override
  void onClose() {
    temperatureController.dispose();
    maxTokensController.dispose();
    maxRoundsController.dispose();
    super.onClose();
  }

  Future<void> loadAll() async {
    if (isRelayMode) {
      // 中继模式下无法直接 HTTP 调用桌面端，跳过加载
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    loadError.value = null;
    try {
      final results = await Future.wait([
        _http.getAsync('/config'),
        _http.getAsync('/scheduler'),
      ]);
      _applyConfig(results[0] as Map<String, dynamic>);
      schedulerTasks.assignAll((results[1] as List).cast<Map<String, dynamic>>());
    } catch (e) {
      loadError.value = '加载失败: $e';
    } finally {
      isLoading.value = false;
    }
  }

  void _applyConfig(Map<String, dynamic> data) {
    final ai = data['ai_model'] as Map<String, dynamic>? ?? {};
    provider.value = ai['provider'] as String? ?? '';
    providerDisplayName.value = ai['providerDisplayName'] as String? ?? '';
    modelId.value = ai['modelId'] as String? ?? '';
    temperature.value = (ai['temperature'] as num?)?.toDouble() ?? 0.7;
    maxTokens.value = ai['maxTokens'] as int? ?? 4096;

    temperatureController.text = temperature.value.toString();
    maxTokensController.text = maxTokens.value.toString();

    final providers = data['providers'] as List? ?? [];
    availableProviders.assignAll(providers.cast<Map<String, dynamic>>());
    _updateAvailableModels();

    final session = data['session'] as Map<String, dynamic>? ?? {};
    maxRounds.value = session['maxRounds'] as int? ?? 20;
    maxRoundsController.text = maxRounds.value.toString();
  }

  void _updateAvailableModels() {
    final p = availableProviders.firstWhereOrNull(
        (e) => e['name'] == provider.value);
    final models = (p?['models'] as List?)?.cast<String>() ?? [];
    availableModels.assignAll(models);
  }

  // ── 修改操作 ──

  Future<void> setProvider(String name) async {
    final result = await _http.postAsync('/config', {
      'ai_model': {'provider': name},
    });
    _applyConfig(result as Map<String, dynamic>);
  }

  Future<void> setModel(String id) async {
    final result = await _http.postAsync('/config', {
      'ai_model': {'modelId': id},
    });
    _applyConfig(result as Map<String, dynamic>);
  }

  Future<void> applyTemperature() async {
    final v = double.tryParse(temperatureController.text.trim());
    if (v == null || v < 0 || v > 2) return;
    final result = await _http.postAsync('/config', {
      'ai_model': {'temperature': v},
    });
    _applyConfig(result as Map<String, dynamic>);
  }

  Future<void> applyMaxTokens() async {
    final v = int.tryParse(maxTokensController.text.trim());
    if (v == null || v < 1) return;
    final result = await _http.postAsync('/config', {
      'ai_model': {'maxTokens': v},
    });
    _applyConfig(result as Map<String, dynamic>);
  }

  Future<void> applyMaxRounds() async {
    final v = int.tryParse(maxRoundsController.text.trim());
    if (v == null || v < 1) return;
    final result = await _http.postAsync('/config', {
      'session': {'maxRounds': v},
    });
    _applyConfig(result as Map<String, dynamic>);
  }

  /// 设置中继文件大小上限（MB），通过 WebSocket 发送到桌面端。
  void setRelayFileMaxMB(int mb) {
    relayFileMaxMB.value = mb;
    final bytes = mb * 1024 * 1024;
    _conn.send({
      'type': 'set_setting',
      'key': 'relay_file_max_bytes',
      'value': bytes,
    });
  }

  void disconnect() {
    _conn.disconnect();
    Get.offAll(() => ConnectionPage());
  }
}
