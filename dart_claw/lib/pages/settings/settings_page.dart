import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/others/model/ai_model_settings_info.dart';
import 'package:dart_claw/pages/settings/settings_logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// 从 home_page 调用：openSettings(context)
void openSettings(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'settings',
    barrierColor: Colors.black.withOpacity(0.6),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, _, __) => const SettingsPage(),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 每次打开时重新创建 logic，关闭时自动销毁
    final logic = Get.put(SettingsLogic());

    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 700,
        height: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D1230), AppColors.bgMid],
              ),
              border: Border(
                left: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            child: Row(
              children: [
                // 左侧分区导航
                _buildNavRail(logic),
                // 右侧内容区
                Expanded(
                  child: Column(
                    children: [
                      _buildHeader(context),
                      Expanded(child: Obx(() => _buildContent(logic))),
                      _buildFooter(logic),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // 左侧导航
  // ─────────────────────────────────────────────────

  Widget _buildNavRail(SettingsLogic logic) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 56), // 对齐 header 高度
          _buildNavItem(
            logic,
            SettingsSection.model,
            Icons.auto_awesome,
            'AI Model',
          ),
          const SizedBox(height: 4),
          _buildNavItem(
            logic,
            SettingsSection.session,
            Icons.chat_bubble_outline,
            'Session',
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    SettingsLogic logic,
    SettingsSection section,
    IconData icon,
    String label,
  ) {
    return Obx(() {
      final isActive = logic.currentSection.value == section;
      return GestureDetector(
        onTap: () => logic.switchSection(section),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withOpacity(0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? AppColors.reasoningAccent : Colors.white38,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isActive ? Colors.white : Colors.white38,
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ─────────────────────────────────────────────────
  // 顶部标题栏
  // ─────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // 内容区分发
  // ─────────────────────────────────────────────────

  Widget _buildContent(SettingsLogic logic) {
    switch (logic.currentSection.value) {
      case SettingsSection.model:
        return _buildModelSection(logic);
      case SettingsSection.session:
        return _buildSessionSection(logic);
    }
  }

  // ─────────────────────────────────────────────────
  // AI 模型 section
  // ─────────────────────────────────────────────────

  Widget _buildModelSection(SettingsLogic logic) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionTitle('Provider'),
        const SizedBox(height: 12),
        // Provider 选择
        Obx(
          () => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AIProvider.values.map((p) {
              final isSelected = logic.selectedProvider.value == p;
              return GestureDetector(
                onTap: () => logic.selectedProvider.value = p,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.25)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.6)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Text(
                    p.displayName,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.white : Colors.white54,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 24),
        _sectionTitle('Model'),
        const SizedBox(height: 12),
        // 模型选择
        Obx(() {
          final models = kProviderModels[logic.selectedProvider.value] ?? [];
          if (models.isEmpty) {
            return _buildInputField(
              label: 'Model ID',
              child: _buildTextField(
                controller: TextEditingController(
                  text: logic.selectedModelId.value,
                ),
                hintText: 'e.g. my-custom-model',
                onChanged: (v) => logic.selectedModelId.value = v,
              ),
            );
          }
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: models.map((m) {
              final isSelected = logic.selectedModelId.value == m;
              return GestureDetector(
                onTap: () => logic.selectedModelId.value = m,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.secondary.withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.secondary.withOpacity(0.5)
                          : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Text(
                    m,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: isSelected ? Colors.white : Colors.white54,
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }),

        const SizedBox(height: 24),
        _sectionTitle('API Key'),
        const SizedBox(height: 12),
        _buildTextField(
          controller: logic.apiKeyController,
          hintText: 'sk-...',
          obscureText: true,
        ),

        // Custom Base URL（仅 custom provider 显示）
        Obx(
          () => logic.selectedProvider.value == AIProvider.custom
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _sectionTitle('Base URL'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: logic.customBaseUrlController,
                      hintText: 'https://your-api.example.com/v1',
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),

        const SizedBox(height: 28),
        _sectionTitle('Temperature'),
        const SizedBox(height: 4),
        Obx(
          () => Column(
            children: [
              Row(
                children: [
                  const Text(
                    '0',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  Expanded(
                    child: Slider(
                      value: logic.temperature.value,
                      min: 0.0,
                      max: 2.0,
                      divisions: 20,
                      activeColor: AppColors.primary,
                      inactiveColor: Colors.white12,
                      onChanged: (v) => logic.temperature.value = double.parse(
                        v.toStringAsFixed(1),
                      ),
                    ),
                  ),
                  const Text(
                    '2',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    logic.temperature.value.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        _sectionTitle('Max Tokens'),
        const SizedBox(height: 12),
        Obx(
          () => _buildTextField(
            controller: TextEditingController(
              text: logic.maxTokens.value.toString(),
            ),
            hintText: '4096',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            // onChanged: (v) => logic.maxTokens.value = int.tryParse(v) ?? 4096,
          ),
        ),

        const SizedBox(height: 12),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // Session section
  // ─────────────────────────────────────────────────

  Widget _buildSessionSection(SettingsLogic logic) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionTitle('Session Preferences'),
        const SizedBox(height: 20),

        // Auto-save 开关
        Obx(
          () => _buildSwitchRow(
            label: 'Auto-save sessions',
            description: 'Automatically save conversation history to disk',
            value: logic.autoSave.value,
            onChanged: (v) => logic.autoSave.value = v,
          ),
        ),

        const SizedBox(height: 28),
        _sectionTitle('History'),
        const SizedBox(height: 12),

        // Max history
        Obx(
          () => _buildTextField(
            controller: TextEditingController(
              text: logic.maxHistoryCount.value.toString(),
            ),
            hintText: '50',
            label: 'Max sessions to keep',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) =>
                logic.maxHistoryCount.value = int.tryParse(v) ?? 50,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Older sessions beyond this limit will be removed automatically.',
          style: TextStyle(fontSize: 12, color: Colors.white38),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // 底部 footer
  // ─────────────────────────────────────────────────

  Widget _buildFooter(SettingsLogic logic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          // 重置按钮
          GestureDetector(
            onTap: () => _confirmReset(logic),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: const Text(
                'Reset Defaults',
                style: TextStyle(fontSize: 13, color: Colors.redAccent),
              ),
            ),
          ),
          const Spacer(),
          // 保存按钮
          GestureDetector(
            onTap: () => logic.save(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.primaryGradient,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReset(SettingsLogic logic) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Reset Settings',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'All settings will be restored to default values. This cannot be undone.',
          style: TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              logic.reset();
            },
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // 通用 UI 辅助组件
  // ─────────────────────────────────────────────────

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.white38,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildInputField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.white60),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String hintText = '',
    String? label,
    bool obscureText = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.white60),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF6366F1),
          ),
        ],
      ),
    );
  }
}
