import 'package:darted_claw/others/model/ai_model_settings_info.dart';
import 'package:darted_claw/others/model/session_settings_info.dart';
import 'package:darted_claw/others/services/app_config_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum SettingsSection { model, session }

class SettingsLogic extends GetxController {
  final currentSection = SettingsSection.model.obs;

  // ─── 表单控制器 ───────────────────────────────────────────────────────────
  late final TextEditingController apiKeyController;
  late final TextEditingController customBaseUrlController;

  // ─── 临时编辑状态（不直接写入 ConfigService，保存时才写入）─────────────
  late final Rx<AIProvider> selectedProvider;
  late final RxString selectedModelId;
  late final RxDouble temperature;
  late final RxInt maxTokens;
  late final RxBool autoSave;
  late final RxInt maxHistoryCount;

  @override
  void onInit() {
    super.onInit();
    final cfg = AppConfigService.shared.config.value;

    selectedProvider = cfg.model.provider.obs;
    selectedModelId = cfg.model.modelId.obs;
    temperature = cfg.model.temperature.obs;
    maxTokens = cfg.model.maxTokens.obs;
    autoSave = cfg.session.autoSave.obs;
    maxHistoryCount = cfg.session.maxHistoryCount.obs;

    apiKeyController = TextEditingController(text: cfg.model.apiKey);
    customBaseUrlController = TextEditingController(
      text: cfg.model.customBaseUrl ?? '',
    );

    // 切换 provider 时，自动选第一个可用模型
    ever(selectedProvider, (provider) {
      final models = kProviderModels[provider] ?? [];
      if (models.isNotEmpty) selectedModelId.value = models.first;
    });
  }

  @override
  void onClose() {
    apiKeyController.dispose();
    customBaseUrlController.dispose();
    super.onClose();
  }

  // ─── 切换当前分区 ─────────────────────────────────────────────────────────
  void switchSection(SettingsSection section) {
    currentSection.value = section;
  }

  // ─── 保存所有设置 ─────────────────────────────────────────────────────────
  Future<void> save() async {
    final modelInfo = AIModelSettingsInfo(
      provider: selectedProvider.value,
      modelId: selectedModelId.value,
      apiKey: apiKeyController.text.trim(),
      temperature: temperature.value,
      maxTokens: maxTokens.value,
      customBaseUrl: selectedProvider.value == AIProvider.custom
          ? customBaseUrlController.text.trim()
          : null,
    );
    final sessionInfo = SessionSettingsInfo(
      autoSave: autoSave.value,
      maxHistoryCount: maxHistoryCount.value,
    );
    await AppConfigService.shared.saveModelSettings(modelInfo);
    await AppConfigService.shared.saveSessionSettings(sessionInfo);
    Get.back();
    Get.snackbar(
      'Saved',
      'Settings saved successfully.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      backgroundColor: const Color(0xFF1A1F3A),
      colorText: Colors.white70,
    );
  }

  // ─── 重置默认值 ───────────────────────────────────────────────────────────
  Future<void> reset() async {
    await AppConfigService.shared.resetToDefaults();
    Get.back();
  }
}
