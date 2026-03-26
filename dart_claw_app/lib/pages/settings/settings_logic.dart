import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../others/network/http_digger.dart';
import '../../others/network/ws_rpc.dart';
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
  final relayFileMaxMB = 100.obs; // 默认 100 MB
  /// 档位：0=小(5–200MB) / 1=中(50MB–1GB) / 2=大(500MB–5GB)
  final relayFileSizeTier = 1.obs;

  static int tierMin(int t) => const [5, 50, 500][t];
  static int tierMax(int t) => const [200, 1000, 5500][t];
  static int tierStep(int t) => const [5, 50, 500][t];

  /// 切换档位时把当前值 snap 到新区间（不复位）。
  void setRelayFileSizeTier(int tier) {
    relayFileSizeTier.value = tier;
    final step = tierStep(tier);
    final snapped = ((relayFileMaxMB.value / step).round() * step)
        .clamp(tierMin(tier), tierMax(tier));
    relayFileMaxMB.value = snapped;
    setRelayFileMaxMB(snapped);
  }

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
      isLoading.value = true;
      loadError.value = null;
      try {
        final results = await Future.wait([
          WsRpc().call('get_config'),
          WsRpc().call('get_scheduler'),
        ]);
        _applyConfig(results[0] as Map<String, dynamic>);
        schedulerTasks.assignAll((results[1] as List).cast<Map<String, dynamic>>());
      } catch (e) {
        loadError.value = '加载失败: $e';
      } finally {
        isLoading.value = false;
      }
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

  Future<void> _postConfig(Map<String, dynamic> body) async {
    final dynamic result;
    if (isRelayMode) {
      result = await WsRpc().call('set_config', body);
    } else {
      result = await _http.postAsync('/config', body);
    }
    _applyConfig(result as Map<String, dynamic>);
  }

  Future<void> setProvider(String name) async {
    await _postConfig({'ai_model': {'provider': name}});
  }

  Future<void> setModel(String id) async {
    await _postConfig({'ai_model': {'modelId': id}});
  }

  Future<void> applyTemperature() async {
    final v = double.tryParse(temperatureController.text.trim());
    if (v == null || v < 0 || v > 2) return;
    await _postConfig({'ai_model': {'temperature': v}});
  }

  Future<void> applyMaxTokens() async {
    final v = int.tryParse(maxTokensController.text.trim());
    if (v == null || v < 1) return;
    await _postConfig({'ai_model': {'maxTokens': v}});
  }

  Future<void> applyMaxRounds() async {
    final v = int.tryParse(maxRoundsController.text.trim());
    if (v == null || v < 1) return;
    await _postConfig({'session': {'maxRounds': v}});
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
    Get.offAll(() => ConnectionPage(), transition: Transition.downToUp);
  }
}
