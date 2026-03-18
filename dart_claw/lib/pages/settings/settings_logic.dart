import 'package:dart_claw/others/model/ai_model_settings_info.dart';
import 'package:dart_claw/others/model/session_settings_info.dart';
import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/others/services/app_config_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum SettingsSection { model, session }

class SettingsLogic extends GetxController {
  final currentSection = SettingsSection.model.obs;

  // ─── 表单控制器 ───────────────────────────────────────────────────────────
  late final TextEditingController apiKeyController;
  late final TextEditingController customBaseUrlController;
  late final TextEditingController maxHistoryCountController;
  late final TextEditingController maxRoundsController;
  late final TextEditingController maxTokensController;

  // ─── 临时编辑状态（不直接写入 ConfigService，保存时才写入）─────────────
  late final Rx<AIProvider> selectedProvider;
  late final RxString selectedModelId;
  late final RxDouble temperature;
  late final RxInt maxTokens;
  late final RxBool autoSave;

  @override
  void onInit() {
    super.onInit();
    final cfg = AppConfigService.shared.config.value;
    final active = cfg.model; // 当前激活 provider 的配置

    selectedProvider = active.provider.obs;
    selectedModelId = active.modelId.obs;
    temperature = active.temperature.obs;
    maxTokens = active.maxTokens.obs;
    autoSave = cfg.session.autoSave.obs;

    maxHistoryCountController = TextEditingController(
        text: cfg.session.maxHistoryCount.toString());
    maxRoundsController = TextEditingController(
        text: cfg.session.maxRounds.toString());
    maxTokensController = TextEditingController(
        text: active.maxTokens.toString());

    apiKeyController = TextEditingController(text: active.apiKey);
    customBaseUrlController = TextEditingController(
      text: active.customBaseUrl ?? '',
    );

    // 切换 provider 时：优先 restore 已保存的配置，否则使用默认值
    ever(selectedProvider, (provider) {
      final saved =
          AppConfigService.shared.config.value.providerConfigs[provider];
      if (saved != null) {
        selectedModelId.value = saved.modelId;
        apiKeyController.text = saved.apiKey;
        temperature.value = saved.temperature;
        maxTokens.value = saved.maxTokens;
        maxTokensController.text = saved.maxTokens.toString();
        customBaseUrlController.text = saved.customBaseUrl ?? '';
      } else {
        final models = kProviderModels[provider] ?? [];
        selectedModelId.value = models.isNotEmpty ? models.first : '';
        apiKeyController.text = '';
        temperature.value = 0.7;
        maxTokens.value = 4096;
        maxTokensController.text = '4096';
        customBaseUrlController.text = '';
      }
    });
  }

  @override
  void onClose() {
    apiKeyController.dispose();
    customBaseUrlController.dispose();
    maxHistoryCountController.dispose();
    maxRoundsController.dispose();
    maxTokensController.dispose();
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
      maxTokens: int.tryParse(maxTokensController.text.trim()) ?? 4096,
      customBaseUrl: selectedProvider.value == AIProvider.custom
          ? customBaseUrlController.text.trim()
          : null,
    );
    final sessionInfo = SessionSettingsInfo(
      autoSave: autoSave.value,
      maxHistoryCount:
          int.tryParse(maxHistoryCountController.text.trim()) ?? 50,
      maxRounds: int.tryParse(maxRoundsController.text.trim()) ?? 20,
    );
    await AppConfigService.shared.saveModelSettings(modelInfo);
    await AppConfigService.shared.saveSessionSettings(sessionInfo);
    Get.back();
    Get.snackbar(
      'Saved',
      'Settings saved successfully.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      backgroundColor: AppColors.dialogBg,
      colorText: Colors.white70,
    );
  }

  // ─── 重置默认值 ───────────────────────────────────────────────────────────
  Future<void> reset() async {
    await AppConfigService.shared.resetToDefaults();
    Get.back();
  }
}
