import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../chat_logic.dart';
import '../dialog/skill_picker_dialog.dart';

/// 从底部滑出的 Session Info & Settings 面板。
/// 通过 showSessionInfoAndSettingsView(context) 打开。
void showSessionInfoAndSettingsView(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SessionInfoAndSettingsView(),
  );
}

class _SessionInfoAndSettingsView extends StatelessWidget {
  const _SessionInfoAndSettingsView();

  @override
  Widget build(BuildContext context) {
    final logic = Get.find<ChatLogic>();
    final minH = MediaQuery.of(context).size.height * 2 / 3;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minH),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            left: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 拖拽把手 ────────────────────────────────────────────────
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
                child: Text(
                  'Session Info',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),

              const _PanelDivider(),

              // ── TOOL CALLS ───────────────────────────────────────────────
              const _SectionHeader('TOOL CALLS'),
              Obx(() => _ToggleRow(
                    label: 'Allow all tool calls',
                    subtitle: 'Skip confirmation for dangerous tools',
                    value: logic.allowAllTools.value,
                    onChanged: (v) => logic.setSetting('allow_all_tools', v),
                  )),

              const SizedBox(height: 16),
              const _PanelDivider(),

              // ── SKILL ────────────────────────────────────────────────────
              const _SectionHeader('SKILL'),
              Obx(() => _ToggleRow(
                    label: 'Allow tool deviation',
                    subtitle:
                        'Warn and continue when agent deviates from skill',
                    value: logic.allowToolDeviation.value,
                    onChanged: (v) =>
                        logic.setSetting('allow_tool_deviation', v),
                  )),
              const SizedBox(height: 12),
              _SkillRow(logic: logic),

              const SizedBox(height: 16),
              const _PanelDivider(),

              // ── SYSTEM ───────────────────────────────────────────────────
              const _SectionHeader('SYSTEM'),
              Obx(() => _ToggleRow(
                    label: 'Auto-fill sudo password',
                    subtitle:
                        'Desktop uses its stored password automatically',
                    value: logic.autoFillSudo.value,
                    onChanged: (v) => logic.setSetting('auto_fill_sudo', v),
                  )),
              // 注意：手机端不提供密码输入框。sudo 密码存储在桌面端本地内存，
              // 移动端仅控制开关，密码需在桌面端直接配置。
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skill 选择行
// ─────────────────────────────────────────────────────────────────────────────

class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.logic});

  final ChatLogic logic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next message skill',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 2),
                Obx(() {
                  final s = logic.pendingSkill.value;
                  return Text(
                    s ?? '自动匹配',
                    style: TextStyle(
                      fontSize: 11,
                      color: s != null ? Colors.orange : Colors.white38,
                      fontWeight:
                          s != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }),
              ],
            ),
          ),
          Obx(() {
            if (logic.pendingSkill.value == null) return const SizedBox.shrink();
            return GestureDetector(
              onTap: () => logic.setSkill(null),
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.close_rounded,
                    size: 16, color: Colors.white38),
              ),
            );
          }),
          GestureDetector(
            onTap: () => SkillPickerDialog.show(context, logic),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Text(
                '选择',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 私有辅助 Widget
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white38,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _PanelDivider extends StatelessWidget {
  const _PanelDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Divider(color: Colors.white12, height: 1),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.white70)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white38)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.amber,
            activeTrackColor: Colors.amber.withValues(alpha: 0.25),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }
}
