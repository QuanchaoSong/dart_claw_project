import 'dart:io';
import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsSkillsLogic extends GetxController {
  final skills = <ClawSkillInfo>[].obs;
  final skillsLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadSkills();
  }
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
    final skillsDir =
        '${Platform.environment['HOME']}/.dart_claw/skills';
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
}
