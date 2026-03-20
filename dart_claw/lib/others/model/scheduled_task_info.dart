import 'package:flutter/material.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum ScheduleMode {
  daily,   // 每天固定时间
  weekly,  // 每周固定星期 + 时间
  once,    // 仅执行一次
}

enum TaskActionType {
  runCommand, // 直接执行 shell 命令
  aiPrompt,   // 作为用户消息触发完整 Agent 对话
}

// ─── ScheduledTaskInfo ──────────────────────────────────────────────────────────

class ScheduledTaskInfo {
  final String id;
  final String name;

  // 调度时间
  final ScheduleMode mode;
  final TimeOfDay time;       // 几点几分触发
  final List<int> weekdays;   // weekly 时有效 (1=周一 … 7=周日，ISO)
  final DateTime? onceAt;     // once 时有效（精确到分钟）

  // 执行动作
  final TaskActionType actionType;
  final String payload; // shell 命令 or AI prompt 文本

  // ── AI 提示词专属 ────────────────────────────────────────────────────────
  final bool allowAllTools;      // 跳过危险工具确认（无人值守建议开启）
  final bool allowToolDeviation; // Skill 偏离时警告后继续
  final String? skillName;       // 绑定的 Skill 名称（null = 自动匹配）

  // ── Shell 命令专属 ───────────────────────────────────────────────────────
  final bool autoFillSudoPassword; // 遇 sudo -S 时自动填入密码
  final String sudoPassword;       // 明文存储于本地 DB

  final bool isEnabled;
  final DateTime? lastRunAt;

  const ScheduledTaskInfo({
    required this.id,
    required this.name,
    required this.mode,
    required this.time,
    this.weekdays = const [],
    this.onceAt,
    required this.actionType,
    required this.payload,
    this.allowAllTools = true,
    this.allowToolDeviation = true,
    this.skillName,
    this.autoFillSudoPassword = false,
    this.sudoPassword = '',
    this.isEnabled = true,
    this.lastRunAt,
  });

  // ── 计算下次触发时间 ─────────────────────────────────────────────────────

  DateTime? get nextRunAt {
    if (!isEnabled) return null;
    final now = DateTime.now();
    switch (mode) {
      case ScheduleMode.daily:
        var candidate = DateTime(
          now.year, now.month, now.day, time.hour, time.minute,
        );
        if (!candidate.isAfter(now)) {
          candidate = candidate.add(const Duration(days: 1));
        }
        return candidate;

      case ScheduleMode.weekly:
        if (weekdays.isEmpty) return null;
        for (var offset = 0; offset < 8; offset++) {
          final day = now.add(Duration(days: offset));
          if (!weekdays.contains(day.weekday)) continue;
          final candidate = DateTime(
            day.year, day.month, day.day, time.hour, time.minute,
          );
          if (candidate.isAfter(now)) return candidate;
        }
        return null;

      case ScheduleMode.once:
        if (onceAt == null) return null;
        final candidate = DateTime(
          onceAt!.year, onceAt!.month, onceAt!.day, time.hour, time.minute,
        );
        return candidate.isAfter(now) ? candidate : null;
    }
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  ScheduledTaskInfo copyWith({
    String? name,
    ScheduleMode? mode,
    TimeOfDay? time,
    List<int>? weekdays,
    DateTime? onceAt,
    TaskActionType? actionType,
    String? payload,
    bool? allowAllTools,
    bool? allowToolDeviation,
    String? skillName,
    bool? autoFillSudoPassword,
    String? sudoPassword,
    bool? isEnabled,
    DateTime? lastRunAt,
  }) =>
      ScheduledTaskInfo(
        id: id,
        name: name ?? this.name,
        mode: mode ?? this.mode,
        time: time ?? this.time,
        weekdays: weekdays ?? this.weekdays,
        onceAt: onceAt ?? this.onceAt,
        actionType: actionType ?? this.actionType,
        payload: payload ?? this.payload,
        allowAllTools: allowAllTools ?? this.allowAllTools,
        allowToolDeviation: allowToolDeviation ?? this.allowToolDeviation,
        skillName: skillName ?? this.skillName,
        autoFillSudoPassword: autoFillSudoPassword ?? this.autoFillSudoPassword,
        sudoPassword: sudoPassword ?? this.sudoPassword,
        isEnabled: isEnabled ?? this.isEnabled,
        lastRunAt: lastRunAt ?? this.lastRunAt,
      );

  // ── DB serialisation ─────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'mode': mode.name,
        'hour': time.hour,
        'minute': time.minute,
        'weekdays': weekdays.join(','),
        'once_at': onceAt?.millisecondsSinceEpoch,
        'action_type': actionType.name,
        'payload': payload,
        'allow_all_tools': allowAllTools ? 1 : 0,
        'allow_tool_deviation': allowToolDeviation ? 1 : 0,
        'skill_name': skillName,
        'auto_fill_sudo_password': autoFillSudoPassword ? 1 : 0,
        'sudo_password': sudoPassword,
        'is_enabled': isEnabled ? 1 : 0,
        'last_run_at': lastRunAt?.millisecondsSinceEpoch,
      };

  factory ScheduledTaskInfo.fromMap(Map<String, dynamic> m) {
    final weekdaysStr = m['weekdays'] as String? ?? '';
    return ScheduledTaskInfo(
      id: m['id'] as String,
      name: m['name'] as String,
      mode: ScheduleMode.values.byName(m['mode'] as String),
      time: TimeOfDay(
        hour: m['hour'] as int,
        minute: m['minute'] as int,
      ),
      weekdays: weekdaysStr.isEmpty
          ? []
          : weekdaysStr.split(',').map(int.parse).toList(),
      onceAt: m['once_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(m['once_at'] as int)
          : null,
      actionType: TaskActionType.values.byName(m['action_type'] as String),
      payload: m['payload'] as String,
      allowAllTools: (m['allow_all_tools'] as int? ?? 1) == 1,
      allowToolDeviation: (m['allow_tool_deviation'] as int? ?? 1) == 1,
      skillName: m['skill_name'] as String?,
      autoFillSudoPassword: (m['auto_fill_sudo_password'] as int? ?? 0) == 1,
      sudoPassword: m['sudo_password'] as String? ?? '',
      isEnabled: (m['is_enabled'] as int) == 1,
      lastRunAt: m['last_run_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(m['last_run_at'] as int)
          : null,
    );
  }
}
