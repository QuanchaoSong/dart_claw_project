import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/pages/home/home_logic.dart';
import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 通用版：不依赖 HomeLogic，直接返回用户选择的 Skill 名称（取消则返回 null）。
Future<String?> showSkillPickerDialogForResult(BuildContext context) async {
  final skills = await ClawSkillLoader.loadAll();
  if (skills.isEmpty) {
    Get.snackbar(
      '没有可用的 Skill',
      '请先在 Settings → Skills 中安装 Skill 文件。',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.dialogBg,
      colorText: Colors.white70,
      duration: const Duration(seconds: 2),
    );
    return null;
  }
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      title: const Row(
        children: [
          Icon(Icons.auto_fix_high_rounded, color: Colors.orange, size: 16),
          SizedBox(width: 8),
          Text('选择 Skill',
              style: TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: skills.map((s) {
            return ListTile(
              dense: true,
              leading: const Icon(Icons.auto_fix_high_rounded,
                  color: Colors.orange, size: 16),
              title: Text(s.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              subtitle: s.description.isNotEmpty
                  ? Text(s.description,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)
                  : null,
              onTap: () => Navigator.of(ctx).pop(s.name),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child:
              const Text('取消', style: TextStyle(color: Colors.white38)),
        ),
      ],
    ),
  );
}

/// 打开 Skill 选择弹窗。用户选定后，通过 [HomeLogic.setPendingSkill] 缓存
/// 到下一条消息发出时使用。
Future<void> showSkillPickerDialog(
    BuildContext context, HomeLogic logic) async {
  final skills = await logic.loadAvailableSkills();

  if (skills.isEmpty) {
    Get.snackbar(
      '没有可用的 Skill',
      '请先在 Settings → Skills 中安装 Skill 文件。',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.dialogBg,
      colorText: Colors.white70,
      duration: const Duration(seconds: 2),
    );
    return;
  }

  await Get.dialog<void>(
    _SkillPickerDialog(skills: skills, logic: logic),
  );
}

class _SkillPickerDialog extends StatelessWidget {
  const _SkillPickerDialog({
    required this.skills,
    required this.logic,
  });

  final List<ClawSkillInfo> skills;
  final HomeLogic logic;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      title: const Row(
        children: [
          Icon(Icons.auto_fix_high_rounded, color: Colors.orange, size: 16),
          SizedBox(width: 8),
          Text('选择 Skill',
              style: TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: skills.map((s) {
            return ListTile(
              dense: true,
              leading: const Icon(Icons.auto_fix_high_rounded,
                  color: Colors.orange, size: 16),
              title: Text(s.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              subtitle: s.description.isNotEmpty
                  ? Text(s.description,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)
                  : null,
              onTap: () {
                logic.setPendingSkill(s.name);
                Get.back();
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: const Text('取消', style: TextStyle(color: Colors.white38)),
        ),
      ],
    );
  }
}
