import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/pages/settings/settings_logic.dart';
import 'package:dart_claw/pages/settings/view/settings_ai_models_view.dart';
import 'package:dart_claw/pages/settings/view/settings_remote_view.dart';
import 'package:dart_claw/pages/settings/view/settings_scheduler_view.dart';
import 'package:dart_claw/pages/settings/view/settings_sessions_view.dart';
import 'package:dart_claw/pages/settings/view/settings_skills_view.dart';
import 'package:flutter/material.dart';
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
          const SizedBox(height: 4),
          _buildNavItem(
            logic,
            SettingsSection.skills,
            Icons.auto_fix_high_rounded,
            'Skills',
          ),
          const SizedBox(height: 4),
          _buildNavItem(
            logic,
            SettingsSection.scheduler,
            Icons.schedule_outlined,
            'Scheduler',
          ),
          const SizedBox(height: 4),
          _buildNavItem(
            logic,
            SettingsSection.remote,
            Icons.phone_iphone_rounded,
            'Remote',
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
        return const SettingsAiModelsView();
      case SettingsSection.session:
        return const SettingsSessionsView();
      case SettingsSection.skills:
        return const SettingsSkillsView();
      case SettingsSection.scheduler:
        return const SettingsSchedulerView();      case SettingsSection.remote:
        return const SettingsRemoteView();    }
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
      child: Obx(() {
        // Skills 页面不显示 Reset/Save，改成 Skills 专属操作栏
        if (logic.currentSection.value == SettingsSection.skills) {
          return Row(
            children: [
              _footerButton(
                icon: Icons.folder_open_outlined,
                label: '打开目录',
                onTap: logic.openSkillsDirectory,
              ),
              const SizedBox(width: 10),
              _footerButton(
                icon: Icons.file_upload_outlined,
                label: '导入 Skill 文件',
                primary: true,
                onTap: logic.importSkillFile,
              ),
            ],
          );
        }
        // Scheduler 和 Remote 页面不需要 footer 按鈕
        if (logic.currentSection.value == SettingsSection.scheduler ||
            logic.currentSection.value == SettingsSection.remote) {
          return const SizedBox.shrink();
        }
        return Row(
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
      );
      }),
    );
  }

  Widget _footerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(colors: AppColors.primaryGradient)
              : null,
          color: primary ? null : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: primary
              ? null
              : Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.white)),
          ],
        ),
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

}
