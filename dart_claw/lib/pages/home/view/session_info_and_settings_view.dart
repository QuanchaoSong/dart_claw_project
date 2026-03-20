import 'package:dart_claw/pages/home/dialog/skill_picker_dialog.dart';
import 'package:dart_claw/pages/home/home_logic.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SessionInfoAndSettingsView extends StatelessWidget {
  const SessionInfoAndSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.find<HomeLogic>();

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16, top: 16, bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── 标题栏 ───────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Info',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 20,
                      ),
                      onPressed: logic.toggleInfoPanel,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ─── 状态信息 ─────────────────────────────────────────────
                Obx(
                  () => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoItem(label: 'Model', value: logic.currentModelId),
                      const _InfoItem(label: 'Tokens', value: '—'),
                      _InfoItem(
                        label: 'Status',
                        value: logic.isRunning.value ? 'Thinking…' : 'Ready',
                      ),
                    ],
                  ),
                ),

                // ─── Session Settings ─────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Colors.white12, height: 1),
                ),
                const Text(
                  'SESSION SETTINGS',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white38,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                Obx(
                  () => _ToggleRow(
                    label: 'Allow all tool calls',
                    subtitle: 'Skip confirmation for dangerous tools',
                    value: logic.allowAllTools.value,
                    onChanged: logic.setAllowAllTools,
                  ),
                ),
                const SizedBox(height: 12),
                Obx(
                  () => _ToggleRow(
                    label: 'Allow tool deviation',
                    subtitle: 'Skill 偏离预定工具时警告后继续，而非立即中止',
                    value: logic.allowToolDeviation.value,
                    onChanged: (v) => logic.allowToolDeviation.value = v,
                  ),
                ),
                const SizedBox(height: 12),
                Obx(
                  () => _ToggleRow(
                    label: 'Auto-fill sudo password',
                    subtitle: 'Skip password dialog for sudo commands',
                    value: logic.autoFillSudoPassword.value,
                    onChanged: (v) => logic.autoFillSudoPassword.value = v,
                  ),
                ),
                Obx(() {
                  if (!logic.autoFillSudoPassword.value) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _InlinePasswordField(
                      controller: logic.sudoPasswordController,
                    ),
                  );
                }),

                // ─── Skill ───────────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Colors.white12, height: 1),
                ),
                const Text(
                  'SKILL',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white38,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                Obx(() {
                  final pending = logic.pendingSkillName.value;
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Next message',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.white70),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pending ?? '自动匹配',
                              style: TextStyle(
                                fontSize: 11,
                                color: pending != null
                                    ? Colors.orange
                                    : Colors.white38,
                                fontWeight: pending != null
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (pending != null)
                        GestureDetector(
                          onTap: () => logic.setPendingSkill(null),
                          child: const Tooltip(
                            message: '清除 Skill',
                            child: Icon(Icons.close_rounded,
                                size: 16, color: Colors.white38),
                          ),
                        ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () =>
                            showSkillPickerDialog(context, logic),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.12)),
                          ),
                          child: const Text(
                            '选择',
                            style: TextStyle(
                                fontSize: 12, color: Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 私有辅助 Widget
// ─────────────────────────────────────────────────────────────────────────────

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.amber,
          activeTrackColor: Colors.amber.withOpacity(0.25),
          inactiveThumbColor: Colors.white38,
          inactiveTrackColor: Colors.white12,
        ),
      ],
    );
  }
}

// ─── 内联密码输入框（带显示/隐藏切换）─────────────────────────────────────────

class _InlinePasswordField extends StatefulWidget {
  const _InlinePasswordField({required this.controller});

  final TextEditingController controller;

  @override
  State<_InlinePasswordField> createState() => _InlinePasswordFieldState();
}

class _InlinePasswordFieldState extends State<_InlinePasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: InputDecoration(
        hintText: 'sudo password',
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: Colors.amber.withOpacity(0.45)),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.white24,
            size: 16,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
