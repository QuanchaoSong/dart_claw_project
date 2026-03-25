import 'package:dart_claw/others/model/server_settings_info.dart';
import 'package:dart_claw/others/services/app_config_service.dart';
import 'package:dart_claw/others/server/local_server.dart';
import 'package:dart_claw/others/tool/hud_tool.dart';
import 'package:dart_claw/pages/settings/view/common_settings_widgets.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Settings → Server 分区
/// 管理服务器开关、端口、连接方式和文件传输目录。
class SettingsRemoteView extends StatefulWidget {
  const SettingsRemoteView({super.key});

  @override
  State<SettingsRemoteView> createState() => _SettingsRemoteViewState();
}

class _SettingsRemoteViewState extends State<SettingsRemoteView> {
  late final TextEditingController _portController;
  final _remote = LocalServer();

  @override
  void initState() {
    super.initState();
    _portController =
        TextEditingController(text: '${_remote.activePort.value}');
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  Future<void> _applyPort() async {
    final port = int.tryParse(_portController.text.trim());
    if (port == null || port <= 1024 || port > 65535) {
      Get.snackbar('端口无效', '请输入 1025 ~ 65535 之间的整数',
          backgroundColor: Colors.red.withValues(alpha: 0.8),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (port == _remote.activePort.value) return;
    await _remote.restart(port);
    setState(() {
      _portController.text = '${_remote.activePort.value}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ── 服务器开关 ────────────────────────────────────────────────────
        settingsSectionTitle('服务器'),
        const SizedBox(height: 12),
        _ServerToggleRow(remote: _remote),

        // ── 启动错误（如有）──────────────────────────────────────────────
        Obx(() {
          final err = _remote.startError.value;
          if (err == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              err,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          );
        }),

        // ── 连接方式（始终显示）──────────────────────────────────────────────
        const SizedBox(height: 24),
        settingsSectionTitle('连接方式'),
        const SizedBox(height: 12),
        _ConnectionModeRow(remote: _remote),

        // ── 端口（直连模式）─────────────────────────────────────────────
        Obx(() {
          if (_remote.connectionMode.value != 'direct') {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              settingsSectionTitle('端口'),
              const SizedBox(height: 4),
              const Text(
                '修改后点击「应用」，服务器将自动重启。',
                style: TextStyle(fontSize: 11, color: Colors.white24),
              ),
              const SizedBox(height: 10),
              _PortRow(controller: _portController, onApply: _applyPort),
            ],
          );
        }),

        // ── 中继配置（中继模式）──────────────────────────────────────────
        Obx(() {
          if (_remote.connectionMode.value != 'relay') {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              settingsSectionTitle('中继配置'),
              const SizedBox(height: 12),
              _RelayConfigSection(remote: _remote),
            ],
          );
        }),

        // ── 二维码（运行中，直连和中继都显示）──────────────────────────────
        Obx(() {
          if (!_remote.isRunning.value) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              settingsSectionTitle('扫码连接'),
              const SizedBox(height: 12),
              _QrSection(remote: _remote),
            ],
          );
        }),

        // ── 文件传输（始终显示）──────────────────────────────────────────
        const SizedBox(height: 24),
        settingsSectionTitle('文件传输'),
        const SizedBox(height: 8),
        const Text(
          '手机端上传的文件保存目录（支持 ~/... 路径）',
          style: TextStyle(fontSize: 12, color: Colors.white38),
        ),
        const SizedBox(height: 12),
        Obx(() {
          final dir =
              AppConfigService.shared.config.value.server.uploadSaveDir;
          return _DirPickerRow(
            path: dir,
            onPick: () async {
              final picked = await getDirectoryPath();
              if (picked != null) {
                AppConfigService.shared.saveServerSettings(
                  AppConfigService.shared.config.value.server
                      .copyWith(uploadSaveDir: picked),
                );
              }
            },
          );
        }),
        const SizedBox(height: 6),
        const Text(
          '修改后立即生效，无需保存。',
          style: TextStyle(fontSize: 11, color: Colors.white24),
        ),
      ],
    );
  }
}

// ── 服务器开关行 ────────────────────────────────────────────────────────────

class _ServerToggleRow extends StatelessWidget {
  const _ServerToggleRow({required this.remote});
  final LocalServer remote;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final running = remote.isRunning.value;
      final isRelay = remote.connectionMode.value == 'relay';

      final IconData icon;
      final String title;
      final String subtitle;
      if (isRelay) {
        icon = Icons.cloud_rounded;
        title = '中继服务';
        subtitle = running ? '已通过中继服务器连接' : '已停止，未连接中继服务器';
      } else {
        icon = Icons.wifi_tethering_rounded;
        title = '本地服务';
        subtitle = running ? '运行中，手机端可连接' : '已停止，手机端无法连接';
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: running ? Colors.greenAccent : Colors.white30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: running ? Colors.white : Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: running
                          ? Colors.greenAccent.withValues(alpha: 0.7)
                          : Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: running,
              activeColor: Colors.greenAccent,
              onChanged: (v) async {
                await AppConfigService.shared.saveServerSettings(
                  AppConfigService.shared.config.value.server
                      .copyWith(isEnabled: v),
                );
                if (v) {
                  await remote.start();
                } else {
                  await remote.stop();
                }
              },
            ),
          ],
        ),
      );
    });
  }
}

// ── 连接方式选择 ────────────────────────────────────────────────────────────

class _ConnectionModeRow extends StatelessWidget {
  const _ConnectionModeRow({required this.remote});
  final LocalServer remote;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final mode = remote.connectionMode.value;
      return Row(
        children: [
          Expanded(
            child: _ModeCard(
              label: '直连（同一 WiFi）',
              icon: Icons.wifi_rounded,
              description: '手机与电脑在同一局域网内',
              selected: mode == 'direct',
              disabled: false,
              onTap: () => remote.setConnectionMode('direct'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ModeCard(
              label: '中继服务器',
              icon: Icons.cloud_rounded,
              description: '跨网络访问',
              selected: mode == 'relay',
              disabled: false,
              onTap: () => remote.setConnectionMode('relay'),
            ),
          ),
        ],
      );
    });
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.label,
    required this.icon,
    required this.description,
    required this.selected,
    required this.disabled,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final String description;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = disabled
        ? Colors.transparent
        : selected
            ? const Color(0xFF6C63FF).withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.04);
    final borderColor = disabled
        ? Colors.white.withValues(alpha: 0.06)
        : selected
            ? const Color(0xFF6C63FF).withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.08);
    final textColor =
        disabled ? Colors.white24 : (selected ? Colors.white : Colors.white54);

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textColor),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                  fontSize: 11,
                  color: disabled ? Colors.white12 : Colors.white24),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 端口设置行 ──────────────────────────────────────────────────────────────

class _PortRow extends StatelessWidget {
  const _PortRow({required this.controller, required this.onApply});
  final TextEditingController controller;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: settingsTextField(
            controller: controller,
            hintText: '37788',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onApply,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Text(
              '应用',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 二维码区域 ──────────────────────────────────────────────────────────────

class _QrSection extends StatelessWidget {
  const _QrSection({required this.remote});
  final LocalServer remote;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final cfg = AppConfigService.shared.config.value.server;
      final code = cfg.securityCode;
      final isRelay = remote.connectionMode.value == 'relay';

      final String qrData;
      final String hint;
      if (isRelay) {
        final rh = cfg.relayHost;
        final rp = cfg.relayPort;
        qrData = 'relay://$rh:$rp?room=$code';
        hint = '手机端扫码 → 自动通过中继服务器连接';
      } else {
        final ip = remote.localIpAddress.value;
        final port = remote.activePort.value;
        qrData = 'ws://$ip:$port?code=$code';
        hint = '手机端打开 Dart Claw App → 设置 → 扫描二维码连接';
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hint,
            style: const TextStyle(fontSize: 12, color: Colors.white38),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    qrData,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white60,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: qrData));
                    HudTool.showInfo('Copied');
                  },
                  child: const Icon(Icons.copy_rounded,
                      size: 14, color: Colors.white38),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // ── 安全码 ──
          _SecurityCodeRow(cfg: cfg),
        ],
      );
    });
  }
}

// ── 中继服务器配置 ──────────────────────────────────────────────────────────

class _RelayConfigSection extends StatefulWidget {
  const _RelayConfigSection({required this.remote});
  final LocalServer remote;

  @override
  State<_RelayConfigSection> createState() => _RelayConfigSectionState();
}

class _RelayConfigSectionState extends State<_RelayConfigSection> {
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  String? _error;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    final cfg = AppConfigService.shared.config.value.server;
    _hostCtrl = TextEditingController(text: cfg.relayHost);
    _portCtrl = TextEditingController(text: '${cfg.relayPort}');
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 37789;
    if (host.isEmpty) {
      setState(() => _error = '请填写中继服务器地址');
      return;
    }
    await AppConfigService.shared.saveServerSettings(
      AppConfigService.shared.config.value.server
          .copyWith(relayHost: host, relayPort: port),
    );
    // 如果正在运行中继模式，重新连接
    if (widget.remote.isRunning.value &&
        widget.remote.connectionMode.value == 'relay') {
      setState(() { _error = null; _connecting = true; });
      try {
        await widget.remote.stop();
        await widget.remote.start();
        if (mounted) {
          final err = widget.remote.startError.value;
          setState(() {
            _connecting = false;
            _error = err;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _connecting = false;
            _error = '中继连接失败：$e';
          });
        }
      }
    } else {
      setState(() => _error = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '中继服务器地址',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: settingsTextField(
                  controller: _hostCtrl,
                  hintText: '例：relay.example.com',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: settingsTextField(
                  controller: _portCtrl,
                  hintText: '37789',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _connecting ? null : _save,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: _connecting
                      ? const CupertinoActivityIndicator(
                          radius: 8,
                          color: Colors.white54,
                        )
                      : const Text(
                          '应用',
                          style:
                              TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_error != null) ...[
            Text(
              _error!,
              style: const TextStyle(fontSize: 11, color: Colors.redAccent),
            ),
            const SizedBox(height: 4),
          ],
          const Text(
            '填写中继服务器地址后点击「应用」。手机端可通过此服务器跨网络连接。',
            style: TextStyle(fontSize: 11, color: Colors.white24),
          ),
        ],
      ),
    );
  }
}

// ── 安全码 + 强度切换 ──────────────────────────────────────────────────────

class _SecurityCodeRow extends StatelessWidget {
  const _SecurityCodeRow({required this.cfg});
  final ServerSettingsInfo cfg;

  void _regenerate(int length) {
    final newCode = ServerSettingsInfo.generateCode(length);
    AppConfigService.shared.saveServerSettings(
      cfg.copyWith(securityCode: newCode, securityCodeLength: length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline,
                  size: 14, color: Colors.white38),
              const SizedBox(width: 8),
              const Text('安全码',
                  style: TextStyle(fontSize: 12, color: Colors.white54)),
              const Spacer(),
              GestureDetector(
                onTap: () => _regenerate(cfg.securityCodeLength),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded,
                        size: 13, color: Colors.white38),
                    SizedBox(width: 4),
                    Text('重新生成',
                        style:
                            TextStyle(fontSize: 11, color: Colors.white38)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 安全码文本
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  cfg.securityCode,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontFamily: 'monospace',
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: cfg.securityCode));
                  HudTool.showInfo('Copied');
                },
                child: const Icon(Icons.copy_rounded,
                    size: 14, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 强度切换
          Row(
            children: [
              const Text('强度',
                  style: TextStyle(fontSize: 11, color: Colors.white30)),
              const SizedBox(width: 10),
              for (final len in [8, 16, 32]) ...[
                if (len != 8) const SizedBox(width: 6),
                _StrengthChip(
                  label: '$len 位',
                  selected: cfg.securityCodeLength == len,
                  onTap: () => _regenerate(len),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StrengthChip extends StatelessWidget {
  const _StrengthChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? const Color(0xFF6C63FF).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? Colors.white : Colors.white38,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── 目录选择行 ──────────────────────────────────────────────────────────────

class _DirPickerRow extends StatelessWidget {
  const _DirPickerRow({required this.path, required this.onPick});

  final String path;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_outlined, size: 16, color: Colors.white38),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              path,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onPick,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(6),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Text(
                '浏览',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
