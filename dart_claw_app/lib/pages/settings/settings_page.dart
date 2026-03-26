import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../others/constants/color_constants.dart';
import '../../others/services/connection_service.dart';
import 'settings_logic.dart';

/// 从右侧滑入设置面板（同桌面端动画风格）。
void openSettings(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'settings',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, _, __) => const SettingsPage(),
    transitionBuilder: (ctx, anim, _, child) {
      final curved =
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween(
                begin: const Offset(1.0, 0.0), end: Offset.zero)
            .animate(curved),
        child: child,
      );
    },
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(SettingsLogic());
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        height: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgMid,
              border: Border(
                left: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const Divider(color: Colors.white12, height: 1),
                  Expanded(
                    child: Obx(() {
                      if (logic.isLoading.value) {
                        return const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        );
                      }
                      final err = logic.loadError.value;
                      if (err != null) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(err,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 13)),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () => logic.loadAll(),
                                  child: const Text('重试'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return _buildContent(logic);
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      child: Row(
        children: [
          const Text(
            '设置',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(SettingsLogic logic) {
    final isRelay = logic.isRelayMode;
    return ListView(
      padding: const EdgeInsets.all(20),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _buildAiModelSection(logic),
        const SizedBox(height: 28),
        _buildSessionSection(logic),
        const SizedBox(height: 28),
        _buildSchedulerSection(logic),
        const SizedBox(height: 28),
        if (isRelay) ...[
          _buildRelaySection(logic),
          const SizedBox(height: 28),
        ],
        _buildConnectionSection(logic),
        const SizedBox(height: 28),
        _buildAboutSection(),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── AI Model ───────────────────────────────────────────────────────────────

  Widget _buildAiModelSection(SettingsLogic logic) {
    return Obx(() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('AI MODEL'),
            const SizedBox(height: 12),
            // Provider 选择
            _SettingsTile(
              label: 'Provider',
              child: _DropdownButton<String>(
                value: logic.provider.value,
                items: logic.availableProviders
                    .map((p) => DropdownMenuItem(
                          value: p['name'] as String,
                          child: Text(p['displayName'] as String,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) logic.setProvider(v);
                },
              ),
            ),
            const SizedBox(height: 8),
            // Model 选择
            _SettingsTile(
              label: 'Model',
              child: logic.availableModels.isEmpty
                  ? Text(logic.modelId.value,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13))
                  : _DropdownButton<String>(
                      value: logic.availableModels
                              .contains(logic.modelId.value)
                          ? logic.modelId.value
                          : null,
                      items: logic.availableModels
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) logic.setModel(v);
                      },
                    ),
            ),
            const SizedBox(height: 8),
            // Temperature
            _SettingsTile(
              label: 'Temperature',
              child: _CompactTextField(
                controller: logic.temperatureController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onSubmitted: (_) => logic.applyTemperature(),
              ),
            ),
            const SizedBox(height: 8),
            // Max Tokens
            _SettingsTile(
              label: 'Max Tokens',
              child: _CompactTextField(
                controller: logic.maxTokensController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: (_) => logic.applyMaxTokens(),
              ),
            ),
          ],
        ));
  }

  // ── Session ────────────────────────────────────────────────────────────────

  Widget _buildSessionSection(SettingsLogic logic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('SESSION'),
        const SizedBox(height: 12),
        _SettingsTile(
          label: 'Max Tool Call Rounds',
          child: _CompactTextField(
            controller: logic.maxRoundsController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => logic.applyMaxRounds(),
          ),
        ),
      ],
    );
  }

  // ── Scheduler ──────────────────────────────────────────────────────────────

  Widget _buildSchedulerSection(SettingsLogic logic) {
    return Obx(() {
      final tasks = logic.schedulerTasks;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('SCHEDULER'),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: const Text(
                '暂无定时任务',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white30, fontSize: 13),
              ),
            )
          else
            ...tasks.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SchedulerTaskTile(task: t),
                )),
        ],
      );
    });
  }

  // ── Relay ────────────────────────────────────────────────────────────────

  Widget _buildRelaySection(SettingsLogic logic) {
    return Obx(() {
      final mb = logic.relayFileMaxMB.value;
      final tier = logic.relayFileSizeTier.value;
      final minMb = SettingsLogic.tierMin(tier);
      final maxMb = SettingsLogic.tierMax(tier);
      final stepMb = SettingsLogic.tierStep(tier);
      final divisions = (maxMb - minMb) ~/ stepMb;
      final sliderValue = mb.toDouble().clamp(minMb.toDouble(), maxMb.toDouble());

      // 显示值：>= 1024 MB 时换算成 GB
      final displayValue = mb >= 1024
          ? '${mb % 1024 == 0 ? mb ~/ 1024 : (mb / 1024).toStringAsFixed(1)} GB'
          : '$mb MB';

      // 区间提示
      final maxLabel = maxMb >= 1024 ? '${maxMb ~/ 1024} GB' : '$maxMb MB';
      final rangeHint = '$minMb MB – $maxLabel';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('中继'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 标题 + 当前值 ──
                Row(
                  children: [
                    const Text('文件中转上限',
                        style: TextStyle(color: Colors.white60, fontSize: 13)),
                    const Spacer(),
                    Text(displayValue,
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 10),
                // ── 档位选择器 ──
                Row(
                  children: List.generate(3, (i) {
                    final labels = ['小', '中', '大'];
                    final selected = tier == i;
                    return Padding(
                      padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
                      child: GestureDetector(
                        onTap: () => logic.setRelayFileSizeTier(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withOpacity(0.18)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary.withOpacity(0.7)
                                  : Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 12,
                              color: selected
                                  ? AppColors.primary
                                  : Colors.white38,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                // ── 滑块 ──
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: Colors.white.withOpacity(0.08),
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withOpacity(0.12),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    min: minMb.toDouble(),
                    max: maxMb.toDouble(),
                    divisions: divisions,
                    value: sliderValue,
                    onChanged: (v) =>
                        logic.relayFileMaxMB.value = v.round(),
                    onChangeEnd: (v) =>
                        logic.setRelayFileMaxMB(v.round()),
                  ),
                ),
                Text(
                  '超过此大小的文件不会通过中继传输（$rangeHint）',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.3), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  // ── Connection ─────────────────────────────────────────────────────────────

  Widget _buildConnectionSection(SettingsLogic logic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('连接'),
        const SizedBox(height: 12),
        Obx(() => _InfoTile(
              label: '服务器',
              value: ConnectionService().isConnected.value
                  ? logic.serverUrl
                  : '未连接',
            )),
        const SizedBox(height: 12),
        Obx(() => ConnectionService().isConnected.value
            ? SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.link_off, size: 16),
                  label: const Text('断开连接'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: logic.disconnect,
                ),
              )
            : const SizedBox.shrink()),
      ],
    );
  }

  // ── About ──────────────────────────────────────────────────────────────────

  Widget _buildAboutSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('关于'),
        SizedBox(height: 12),
        _InfoTile(label: '版本', value: '1.0.0'),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        color: Colors.white38,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 13)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 13)),
          const Spacer(),
          child,
        ],
      ),
    );
  }
}

class _DropdownButton<T> extends StatelessWidget {
  const _DropdownButton({
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
  });
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: AppColors.bgSurface,
      underline: const SizedBox.shrink(),
      isDense: true,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      icon: const Icon(Icons.expand_more, color: Colors.white38, size: 18),
    );
  }
}

class _CompactTextField extends StatefulWidget {
  const _CompactTextField({
    required this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_CompactTextField> createState() => _CompactTextFieldState();
}

class _CompactTextFieldState extends State<_CompactTextField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // 焦点丢失时触发保存，覆盖「拖拽收键盘」「点击别处」等所有收键盘方式
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        widget.onSubmitted?.call(widget.controller.text);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        onSubmitted: widget.onSubmitted,
        textAlign: TextAlign.right,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _SchedulerTaskTile extends StatelessWidget {
  const _SchedulerTaskTile({required this.task});
  final Map<String, dynamic> task;

  @override
  Widget build(BuildContext context) {
    final name = task['name'] as String? ?? '';
    final mode = task['mode'] as String? ?? '';
    final time = task['time'] as String? ?? '';
    final enabled = task['isEnabled'] as bool? ?? false;
    final actionType = task['actionType'] as String? ?? '';
    final weekdays = (task['weekdays'] as List?)?.join(', ') ?? '';

    String schedule;
    switch (mode) {
      case 'daily':
        schedule = '每天 $time';
      case 'weekly':
        schedule = '每周 $weekdays $time';
      case 'once':
        schedule = '一次性 $time';
      default:
        schedule = time;
    }

    final actionIcon = actionType == 'aiPrompt'
        ? Icons.smart_toy_outlined
        : Icons.terminal_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Icon(actionIcon, size: 16, color: Colors.white38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                      color: enabled ? Colors.white : Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    )),
                const SizedBox(height: 2),
                Text(schedule,
                    style:
                        const TextStyle(color: Colors.white30, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.primary.withOpacity(0.15)
                  : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              enabled ? '启用' : '停用',
              style: TextStyle(
                fontSize: 10,
                color: enabled ? AppColors.primary : Colors.white30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
