import 'package:dart_claw/pages/settings/skills/settings_skills_logic.dart';
import 'package:dart_claw/pages/settings/view/common_settings_widgets.dart';
import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsSkillsView extends StatelessWidget {
  const SettingsSkillsView({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(SettingsSkillsLogic());
    return Obx(() {
      if (logic.skillsLoading.value) {
        return const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white38,
          ),
        );
      }

      final skills = logic.skills;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Row(
              children: [
                settingsSectionTitle('已安装的 Skills'),
                const Spacer(),
                _RefreshButton(onTap: logic.loadSkills),
              ],
            ),
          ),
          Expanded(
            child: skills.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: skills.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) =>
                        _SkillCard(skill: skills[i], logic: logic),
                  ),
          ),
        ],
      );
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_fix_high_rounded,
              size: 40, color: Colors.white12),
          const SizedBox(height: 16),
          const Text(
            '还没有安装任何 Skill',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            '点击底部「导入 Skill 文件」或「打开目录」手动添加',
            style: TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─── Skill 卡片 ───────────────────────────────────────────────────────────────

class _SkillCard extends StatefulWidget {
  const _SkillCard({required this.skill, required this.logic});

  final ClawSkillInfo skill;
  final SettingsSkillsLogic logic;

  @override
  State<_SkillCard> createState() => _SkillCardState();
}

class _SkillCardState extends State<_SkillCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final skill = widget.skill;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 主行 ──
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_fix_high_rounded,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          skill.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (skill.description.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            skill.description,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                            maxLines: _expanded ? null : 2,
                            overflow: _expanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 步骤数 / 参数数 badge
                  _MetaBadge(
                    '${skill.steps.length} 步骤',
                    Icons.checklist_rounded,
                  ),
                  const SizedBox(width: 6),
                  if (skill.parameters.isNotEmpty)
                    _MetaBadge(
                      '${skill.parameters.length} 参数',
                      Icons.tune_rounded,
                    ),
                  const SizedBox(width: 8),
                  // 展开箭头
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: Colors.white38),
                  ),
                ],
              ),
            ),
          ),

          // ── 展开详情 ──
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 12),

                  // 参数列表
                  if (skill.parameters.isNotEmpty) ...[
                    _detailLabel('参数'),
                    const SizedBox(height: 6),
                    ...skill.parameters.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: Colors.blue.withOpacity(0.3)),
                                ),
                                child: Text(
                                  p.name,
                                  style: const TextStyle(
                                      color: Colors.lightBlueAccent,
                                      fontSize: 11,
                                      fontFamily: 'monospace'),
                                ),
                              ),
                              if (p.required)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Text('*',
                                      style: TextStyle(
                                          color: Colors.orange, fontSize: 11)),
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  p.description,
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 10),
                  ],

                  // 步骤列表
                  _detailLabel('步骤'),
                  const SizedBox(height: 6),
                  ...skill.steps.asMap().entries.map((e) {
                    final idx = e.key;
                    final step = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.orange.withOpacity(0.4)),
                            ),
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.title,
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                ),
                                if (step.expectedTools.isNotEmpty)
                                  Text(
                                    '工具: ${step.expectedTools.join(', ')}',
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 10),
                  // 删除按钮
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => _confirmDelete(context, widget.skill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: Colors.red.withOpacity(0.2)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 13, color: Colors.redAccent),
                            SizedBox(width: 4),
                            Text('删除',
                                style: TextStyle(
                                    color: Colors.redAccent, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailLabel(String text) {
    return Text(text,
        style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8));
  }

  void _confirmDelete(BuildContext context, ClawSkillInfo skill) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1C1C2E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('删除 Skill',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        content: Text(
          '确定要删除「${skill.name}」吗？此操作会删除本地文件，不可撤销。',
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('取消',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              widget.logic.deleteSkill(skill);
            },
            child: const Text('删除',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ─── 小工具 ───────────────────────────────────────────────────────────────────

class _MetaBadge extends StatelessWidget {
  const _MetaBadge(this.label, this.icon);

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white38),
          const SizedBox(width: 4),
          Text(label,
              style:
                  const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
        ),
        child:
            const Icon(Icons.refresh_rounded, size: 14, color: Colors.white38),
      ),
    );
  }
}
