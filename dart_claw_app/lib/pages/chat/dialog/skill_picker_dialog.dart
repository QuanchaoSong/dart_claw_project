import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../chat_logic.dart';

/// 从下方弹出、让用户为下一条消息选择 Skill 的选择器。
/// 由 SkillPickerDialog.show(context, logic) 调用。
class SkillPickerDialog extends StatelessWidget {
  const SkillPickerDialog({super.key, required this.logic});

  final ChatLogic logic;

  /// 拉取 Skill 列表后弹出选择器。使用根路由层（useRootNavigator: true），
  /// 因此可被安全地从任何底部面板内调用，不会被父路由拦截。
  static Future<void> show(BuildContext context, ChatLogic logic) async {
    await logic.fetchSkills();

    if (logic.availableSkills.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          Navigator.of(context, rootNavigator: true).context,
        ).showSnackBar(
          const SnackBar(
            content: Text('No skills found on desktop'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SkillPickerDialog(logic: logic),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          left: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽把手
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose a Skill',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Flexible(
            child: Obx(() => ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: logic.availableSkills.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (_, i) {
                    final skill = logic.availableSkills[i];
                    final isSelected =
                        logic.pendingSkill.value == skill.name;
                    return GestureDetector(
                      onTap: () {
                        logic.setSkill(isSelected ? null : skill.name);
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.orange.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? Colors.orange.withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    skill.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected
                                          ? Colors.orange
                                          : Colors.white,
                                    ),
                                  ),
                                  if (skill.description.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      skill.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white38),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_rounded,
                                  size: 16, color: Colors.orange),
                          ],
                        ),
                      ),
                    );
                  },
                )),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
