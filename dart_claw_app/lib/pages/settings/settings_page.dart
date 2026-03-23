import 'package:flutter/material.dart';
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
                  Expanded(child: _buildContent(logic)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

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

  // ── Content ────────────────────────────────────────────────────────────────

  Widget _buildContent(SettingsLogic logic) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildConnectionSection(logic),
        const SizedBox(height: 40),
        _buildAboutSection(),
      ],
    );
  }

  Widget _buildConnectionSection(SettingsLogic logic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('连接信息'),
        const SizedBox(height: 12),
        Obx(() => _InfoTile(
              label: '服务器',
              value: ConnectionService().isConnected.value
                  ? logic.serverUrl
                  : '未连接',
            )),
        const SizedBox(height: 16),
        Obx(() => ConnectionService().isConnected.value
            ? _buildDisconnectButton(logic)
            : const SizedBox.shrink()),
      ],
    );
  }

  Widget _buildDisconnectButton(SettingsLogic logic) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.link_off, size: 16),
        label: const Text('断开连接'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: const BorderSide(color: Colors.redAccent),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: logic.disconnect,
      ),
    );
  }

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

// ─── Shared widgets ────────────────────────────────────────────────────────────

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
