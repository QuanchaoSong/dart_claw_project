import 'package:dart_claw/others/model/ai_model_settings_info.dart';
import 'package:dart_claw/others/model/session_settings_info.dart';
import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/others/services/app_config_service.dart';
import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';

enum SettingsSection { model, session, skills, scheduler }

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
  late final RxBool browserRememberLogin;
  late final RxBool askUserUseDialog;

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
    browserRememberLogin = cfg.session.browserRememberLogin.obs;
    askUserUseDialog = cfg.session.askUserUseDialog.obs;

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

  // ─── Skills 状态 ────────────────────────────────────────────────────────
  final skills = <ClawSkillInfo>[].obs;
  final skillsLoading = false.obs;

  Future<void> loadSkills() async {
    skillsLoading.value = true;
    try {
      final loaded = await ClawSkillLoader.loadAll();
      skills.assignAll(loaded);
    } finally {
      skillsLoading.value = false;
    }
  }

  Future<void> importSkillFile() async {
    const typeGroup = XTypeGroup(
      label: 'Markdown',
      extensions: ['md'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    final skillsDir = Directory(
        '${Platform.environment['HOME']}/.dart_claw/skills');
    await skillsDir.create(recursive: true);

    final dest = File('${skillsDir.path}/${file.name}');
    await File(file.path).copy(dest.path);
    await loadSkills();

    Get.snackbar(
      'Skill 已导入',
      file.name,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      backgroundColor: AppColors.dialogBg,
      colorText: Colors.white70,
    );
  }

  Future<void> openSkillsDirectory() async {
    final dir = Directory(
        '${Platform.environment['HOME']}/.dart_claw/skills');
    await dir.create(recursive: true);
    await Process.run('open', [dir.path]);
  }

  Future<void> deleteSkill(ClawSkillInfo skill) async {
    final skillsDir = '${Platform.environment['HOME']}/.dart_claw/skills';
    // ClawSkillLoader 加载的文件名由 skill.name 无法直接反推，
    // 扫描目录匹配解析后 name 相同的文件来删除。
    final dir = Directory(skillsDir);
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.md')) continue;
      try {
        final content = await entity.readAsString();
        if (content.contains('name: ${skill.name}')) {
          await entity.delete();
          break;
        }
      } catch (_) {}
    }
    await loadSkills();
  }

  // ─── 切换当前分区 ─────────────────────────────────────────────────────────
  void switchSection(SettingsSection section) {
    if (section == SettingsSection.skills) loadSkills();
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
      browserRememberLogin: browserRememberLogin.value,
      askUserUseDialog: askUserUseDialog.value,
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
  // ─── 清除浏览器登录数据 ───────────────────────────────────────────────
  Future<void> clearBrowserData() async {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ?? '';
    final profileDir = Directory('$home/.dart_claw/browser_profile');
    if (await profileDir.exists()) {
      await profileDir.delete(recursive: true);
    }
    Get.snackbar(
      'Browser Data Cleared',
      'Login sessions have been removed. You will need to log in again.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
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
