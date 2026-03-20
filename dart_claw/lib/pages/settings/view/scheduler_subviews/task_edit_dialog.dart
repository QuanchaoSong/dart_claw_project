import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/others/model/scheduled_task_info.dart';
import 'package:dart_claw/others/services/scheduler_service.dart';
import 'package:dart_claw/pages/home/dialog/skill_picker_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ─── Edit / Create dialog ─────────────────────────────────────────────────────

class TaskEditDialog extends StatefulWidget {
  const TaskEditDialog({super.key, this.existing});
  final ScheduledTaskInfo? existing;

  @override
  State<TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends State<TaskEditDialog> {
  final _nameCtrl = TextEditingController();
  final _payloadCtrl = TextEditingController();

  ScheduleMode _mode = ScheduleMode.daily;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  List<int> _weekdays = [1, 2, 3, 4, 5];
  DateTime? _onceAt;
  TaskActionType _actionType = TaskActionType.runCommand;

  // ── 执行设置 ──────────────────────────────────────────────────────────────
  bool _allowAllTools = true;
  bool _allowToolDeviation = true;
  String? _selectedSkillName;
  bool _autoFillSudo = false;
  final _sudoPasswordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    if (t != null) {
      _nameCtrl.text = t.name;
      _payloadCtrl.text = t.payload;
      _mode = t.mode;
      _time = t.time;
      _weekdays = List.from(t.weekdays);
      _onceAt = t.onceAt;
      _actionType = t.actionType;
      _allowAllTools = t.allowAllTools;
      _allowToolDeviation = t.allowToolDeviation;
      _selectedSkillName = t.skillName;
      _autoFillSudo = t.autoFillSudoPassword;
      _sudoPasswordCtrl.text = t.sudoPassword;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _payloadCtrl.dispose();
    _sudoPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.secondary,
            surface: AppColors.dialogBg,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _onceAt ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.secondary,
            surface: AppColors.dialogBg,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _onceAt = picked);
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final payload = _payloadCtrl.text.trim();
    if (name.isEmpty || payload.isEmpty) {
      Get.snackbar(
        '提示',
        '名称和内容不能为空',
        backgroundColor: AppColors.dialogBg,
        colorText: Colors.white70,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final svc = SchedulerService.instance;
    final existing = widget.existing;

    final task = ScheduledTaskInfo(
      id: existing?.id ?? _genId(),
      name: name,
      mode: _mode,
      time: _time,
      weekdays: _mode == ScheduleMode.weekly ? _weekdays : [],
      onceAt: _mode == ScheduleMode.once ? _onceAt : null,
      actionType: _actionType,
      payload: payload,
      isEnabled: existing?.isEnabled ?? true,
      lastRunAt: existing?.lastRunAt,
      allowAllTools: _allowAllTools,
      allowToolDeviation: _allowToolDeviation,
      skillName: _selectedSkillName,
      autoFillSudoPassword: _autoFillSudo,
      sudoPassword: _sudoPasswordCtrl.text.trim(),
    );

    if (existing == null) {
      svc.addTask(task);
    } else {
      svc.updateTask(task);
    }

    Navigator.of(context).pop();
  }

  String _genId() {
    final t = DateTime.now().microsecondsSinceEpoch;
    return (t ^ (t >> 16)).toRadixString(36);
  }

  Future<void> _pickSkill() async {
    final picked = await showSkillPickerDialogForResult(context);
    if (picked != null) setState(() => _selectedSkillName = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      backgroundColor: AppColors.dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      child: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEdit ? '编辑任务' : '新建任务',
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),

              _Label('任务名称'),
              const SizedBox(height: 6),
              _Field(controller: _nameCtrl, hint: '例：清理 XX 缓存'),
              const SizedBox(height: 16),

              _Label('执行频率'),
              const SizedBox(height: 6),
              _SegmentedRow(
                options: const ['每天', '每周', '仅一次'],
                selected: _mode.index,
                onSelected: (i) => setState(() => _mode = ScheduleMode.values[i]),
              ),
              const SizedBox(height: 12),

              _Label('触发时间'),
              const SizedBox(height: 6),
              Row(
                children: [
                  _TimeChip(label: _formatTime(_time), onTap: _pickTime),
                  if (_mode == ScheduleMode.once) ...[
                    const SizedBox(width: 8),
                    _TimeChip(
                      label: _onceAt == null
                          ? '选择日期'
                          : '${_onceAt!.month}/${_onceAt!.day}',
                      onTap: _pickDate,
                    ),
                  ],
                ],
              ),

              if (_mode == ScheduleMode.weekly) ...[
                const SizedBox(height: 12),
                _Label('重复星期'),
                const SizedBox(height: 6),
                _WeekdayPicker(
                  selected: _weekdays,
                  onChanged: (days) => setState(() => _weekdays = days),
                ),
              ],

              const SizedBox(height: 16),

              _Label('执行动作'),
              const SizedBox(height: 6),
              _SegmentedRow(
                options: const ['AI 提示词', 'Shell 命令'],
                selected: _actionType == TaskActionType.aiPrompt ? 0 : 1,
                onSelected: (i) => setState(() =>
                    _actionType = i == 0
                        ? TaskActionType.aiPrompt
                        : TaskActionType.runCommand),
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _payloadCtrl,
                hint: _actionType == TaskActionType.runCommand
                    ? '例：rm -rf ~/Library/Caches/com.xxx.app'
                    : '例：通过飞书机器人 Webhook 发送早安消息...',
                minLines: 3,
                maxLines: 6,
              ),

              const SizedBox(height: 16),

              // ── 执行设置 ────────────────────────────────────
              _Label('执行设置'),
              const SizedBox(height: 10),
              if (_actionType == TaskActionType.aiPrompt) ...[  
                _TaskToggleRow(
                  label: 'Allow all tools',
                  subtitle: '跳过危险工具确认（无人值守建议开启）',
                  value: _allowAllTools,
                  onChanged: (v) => setState(() => _allowAllTools = v),
                ),
                const SizedBox(height: 10),
                _TaskToggleRow(
                  label: 'Allow tool deviation',
                  subtitle: 'Skill 偏离时警告后继续而非中止',
                  value: _allowToolDeviation,
                  onChanged: (v) => setState(() => _allowToolDeviation = v),
                ),
                const SizedBox(height: 10),
                _SkillPickerRow(
                  selected: _selectedSkillName,
                  onClear: () => setState(() => _selectedSkillName = null),
                  onPick: _pickSkill,
                ),
                const SizedBox(height: 10),
                _TaskToggleRow(
                  label: 'Auto-fill sudo password',
                  subtitle: 'AI 执行含 sudo -S 脚本时自动填入（明文存储于本地 DB）',
                  value: _autoFillSudo,
                  onChanged: (v) => setState(() => _autoFillSudo = v),
                ),
                if (_autoFillSudo) ...[  
                  const SizedBox(height: 8),
                  _Field(
                    controller: _sudoPasswordCtrl,
                    hint: 'Sudo 密码',
                    obscureText: true,
                  ),
                ],
              ],
              if (_actionType == TaskActionType.runCommand) ...[  
                _TaskToggleRow(
                  label: 'Auto-fill sudo password',
                  subtitle: '命令中含 sudo -S 时自动填入（明文存储于本地 DB）',
                  value: _autoFillSudo,
                  onChanged: (v) => setState(() => _autoFillSudo = v),
                ),
                if (_autoFillSudo) ...[  
                  const SizedBox(height: 8),
                  _Field(
                    controller: _sudoPasswordCtrl,
                    hint: 'Sudo 密码',
                    obscureText: true,
                  ),
                ],
              ],

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消', style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _save,
                    child: Text(isEdit ? '保存' : '创建'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ─── Small reusable widgets ───────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(color: Colors.white54, fontSize: 12));
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.obscureText = false,
  });
  final TextEditingController controller;
  final String hint;
  final int minLines;
  final int maxLines;
  final bool obscureText;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        minLines: minLines,
        maxLines: maxLines,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: AppColors.secondary),
          ),
        ),
      );
}

class _SegmentedRow extends StatelessWidget {
  const _SegmentedRow({
    required this.options,
    required this.selected,
    required this.onSelected,
  });
  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(options.length, (i) {
        final isActive = i == selected;
        return GestureDetector(
          onTap: () => onSelected(i),
          child: Container(
            margin: EdgeInsets.only(right: i < options.length - 1 ? 6 : 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withOpacity(0.3)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isActive
                    ? AppColors.secondary.withOpacity(0.6)
                    : Colors.white.withOpacity(0.1),
              ),
            ),
            child: Text(
              options[i],
              style: TextStyle(
                color: isActive ? AppColors.secondary : Colors.white54,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.secondary.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.access_time, size: 14, color: AppColors.secondary),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onChanged});
  final List<int> selected;
  final ValueChanged<List<int>> onChanged;

  static const _labels = ['', '一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (i) {
        final day = i + 1;
        final isOn = selected.contains(day);
        return GestureDetector(
          onTap: () {
            final next = List<int>.from(selected);
            isOn ? next.remove(day) : next.add(day);
            onChanged(next);
          },
          child: Container(
            width: 36,
            height: 36,
            margin: EdgeInsets.only(right: i < 6 ? 6 : 0),
            decoration: BoxDecoration(
              color: isOn
                  ? AppColors.primary.withOpacity(0.3)
                  : Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: isOn
                    ? AppColors.secondary.withOpacity(0.7)
                    : Colors.white.withOpacity(0.1),
              ),
            ),
            child: Center(
              child: Text(
                _labels[day],
                style: TextStyle(
                  color: isOn ? AppColors.secondary : Colors.white38,
                  fontSize: 12,
                  fontWeight: isOn ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Execution-settings widgets ───────────────────────────────────────────────

class _TaskToggleRow extends StatelessWidget {
  const _TaskToggleRow({
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
              Text(label,
                  style: const TextStyle(fontSize: 13, color: Colors.white70)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.white38)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.secondary,
          activeTrackColor: AppColors.secondary.withOpacity(0.25),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}

class _SkillPickerRow extends StatelessWidget {
  const _SkillPickerRow({
    required this.selected,
    required this.onClear,
    required this.onPick,
  });
  final String? selected;
  final VoidCallback onClear;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.auto_fix_high_rounded, size: 14, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('运行 Skill',
                  style: TextStyle(fontSize: 13, color: Colors.white70)),
              const SizedBox(height: 2),
              Text(
                selected ?? '自动匹配',
                style: TextStyle(
                  fontSize: 11,
                  color: selected != null ? Colors.orange : Colors.white38,
                  fontWeight:
                      selected != null ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        if (selected != null)
          GestureDetector(
            onTap: onClear,
            child: const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.close_rounded, size: 16, color: Colors.white38),
            ),
          ),
        GestureDetector(
          onTap: onPick,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: const Text('选择',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
          ),
        ),
      ],
    );
  }
}
