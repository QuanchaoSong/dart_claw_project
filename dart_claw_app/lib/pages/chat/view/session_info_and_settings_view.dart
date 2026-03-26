import 'dart:async';
import 'package:dart_claw_app/others/tool/global_tool.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../chat_logic.dart';
import '../dialog/skill_picker_dialog.dart';

/// 从底部滑出的 Session Info & Settings 面板。
/// 通过 showSessionInfoAndSettingsView(context) 打开。
void showSessionInfoAndSettingsView(BuildContext context) {
  hideKeyboard(context);

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

              // ── 模型 / Token 统计 ─────────────────────────────────────────────
              Obx(() {
                final model = logic.sessionModelId.value;
                final tokens = logic.sessionTokens.value;
                final hasInfo = model.isNotEmpty || tokens > 0;
                if (!hasInfo) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Row(
                    children: [
                      if (model.isNotEmpty) ...[
                        const Icon(Icons.auto_awesome_rounded,
                            size: 12, color: Colors.white38),
                        const SizedBox(width: 4),
                        Text(
                          model,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white38),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (tokens > 0) ...[
                        const Icon(Icons.data_usage_rounded,
                            size: 12, color: Colors.white38),
                        const SizedBox(width: 4),
                        Text(
                          '$tokens tokens',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white38),
                        ),
                      ],
                    ],
                  ),
                );
              }),

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
              Obx(() {
                if (!logic.autoFillSudo.value) return const SizedBox.shrink();
                return _SudoPasswordField(logic: logic);
              }),
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

// ─────────────────────────────────────────────────────────────────────────────
// sudo 密码输入块（开关打开时才显示）
// ─────────────────────────────────────────────────────────────────────────────

class _SudoPasswordField extends StatefulWidget {
  const _SudoPasswordField({required this.logic});
  final ChatLogic logic;

  @override
  State<_SudoPasswordField> createState() => _SudoPasswordFieldState();
}

class _SudoPasswordFieldState extends State<_SudoPasswordField> {
  final _controller = TextEditingController();
  Timer? _debounce;
  var _obscure = true;
  var _sent = false; // 头像标记第一次发送后变为 ✓

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      widget.logic.setSudoPasswordSetting(value.trim());
      if (mounted && value.trim().isNotEmpty) setState(() => _sent = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: TextField(
        controller: _controller,
        obscureText: _obscure,
        onChanged: _onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: '输入 sudo 密码…',
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.amber),
          ),
          // 显示/隐藏 + 已同步标记
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_sent)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.check_circle_rounded,
                      size: 14, color: Colors.green),
                ),
              IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white38,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ],
          ),
        ),
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
