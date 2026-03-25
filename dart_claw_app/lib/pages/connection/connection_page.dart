import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../others/constants/color_constants.dart';
import 'connection_logic.dart';
import 'scanner_page.dart';

// ════════════════════════════════════════════════════════════════════════════
// ConnectionPage — 主连接页面
// ════════════════════════════════════════════════════════════════════════════

class ConnectionPage extends StatelessWidget {
  ConnectionPage({super.key});

  final logic = Get.put(ConnectionLogic());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E1A), Color(0xFF0D1230), Color(0xFF111827)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Column(
              children: [
                _buildLogo(),
                const SizedBox(height: 36),
                _buildSegmentedTab(),
                const SizedBox(height: 28),
                Obx(() {
                  switch (logic.selectedTab.value) {
                    case 0:
                      return _buildScanTab();
                    case 2:
                      return _buildRelayTab();
                    default:
                      return _buildManualTab();
                  }
                }),
                Obx(() {
                  final msg = logic.errorMessage.value;
                  if (msg == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(msg,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13)),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Logo ──────────────────────────────────────────────────────────────────

  Widget _buildLogo() {
    return const Column(
      children: [
        Text('🦞', style: TextStyle(fontSize: 56)),
        SizedBox(height: 12),
        Text('Dart Claw',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        SizedBox(height: 4),
        Text('Remote Control',
            style: TextStyle(fontSize: 13, color: Colors.white38)),
      ],
    );
  }

  // ── Segmented tab ─────────────────────────────────────────────────────────

  Widget _buildSegmentedTab() {
    return Obx(() => Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _tabItem(0, Icons.qr_code_scanner_rounded, '扫码'),
              _tabItem(1, Icons.keyboard_rounded, '手动'),
              _tabItem(2, Icons.cloud_outlined, '中继'),
            ],
          ),
        ));
  }

  Widget _tabItem(int index, IconData icon, String label) {
    final selected = logic.selectedTab.value == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => logic.selectedTab.value = index,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? Colors.white : Colors.white38),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? Colors.white : Colors.white38,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // ── Scan tab ──────────────────────────────────────────────────────────────

  Widget _buildScanTab() {
    return Obx(() {
      final busy = logic.isConnecting.value;
      return Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(Icons.qr_code_2_rounded,
                size: 52, color: Colors.white54),
          ),
          const SizedBox(height: 24),
          const Text('扫描桌面端二维码',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Text('在桌面端 Server 设置中找到二维码',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.35))),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: busy
                    ? null
                    : const LinearGradient(
                        colors: AppColors.primaryGradient),
                color: busy
                    ? Colors.white.withValues(alpha: 0.08)
                    : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final result = await Get.to<String>(
                            () => const ScannerPage(),
                            fullscreenDialog: true,
                            transition: Transition.downToUp);
                        if (result != null) logic.connectFromQr(result);
                      },
                icon: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white70),
                        ),
                      )
                    : const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 20),
                label: Text(busy ? '正在连接…' : '开始扫描',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  // ── Manual tab ────────────────────────────────────────────────────────────

  Widget _buildManualTab() {
    return Column(
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: logic.hostController,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: const InputDecoration(
            labelText: 'Server IP',
            prefixIcon: Icon(Icons.computer_outlined,
                color: Colors.white38, size: 20),
          ),
          onSubmitted: (_) => logic.connect(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: logic.portController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: const InputDecoration(
            labelText: 'Port',
            prefixIcon: Icon(Icons.settings_ethernet,
                color: Colors.white38, size: 20),
          ),
          onSubmitted: (_) => logic.connect(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: logic.codeController,
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            labelText: 'Security Code',
            prefixIcon:
                Icon(Icons.lock_outline, color: Colors.white38, size: 20),
          ),
          onSubmitted: (_) => logic.connect(),
        ),
        const SizedBox(height: 24),
        Obx(() {
          final busy = logic.isConnecting.value;
          return SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: busy
                    ? null
                    : const LinearGradient(
                        colors: AppColors.primaryGradient),
                color: busy
                    ? Colors.white.withValues(alpha: 0.08)
                    : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: busy ? null : logic.connect,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white70),
                        ),
                      )
                    : const Text('连接',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Relay tab ─────────────────────────────────────────────────────────────

  Widget _buildRelayTab() {
    return Column(
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: logic.relayHostController,
          keyboardType: TextInputType.url,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: const InputDecoration(
            labelText: '中继服务器地址',
            prefixIcon:
                Icon(Icons.cloud_outlined, color: Colors.white38, size: 20),
          ),
          onSubmitted: (_) => logic.connectRelay(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: logic.relayPortController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: const InputDecoration(
            labelText: '端口',
            prefixIcon: Icon(Icons.settings_ethernet,
                color: Colors.white38, size: 20),
          ),
          onSubmitted: (_) => logic.connectRelay(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: logic.relayCodeController,
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            labelText: '安全码（桌面端 Security Code）',
            prefixIcon:
                Icon(Icons.lock_outline, color: Colors.white38, size: 20),
          ),
          onSubmitted: (_) => logic.connectRelay(),
        ),
        const SizedBox(height: 24),
        Obx(() {
          final busy = logic.isConnecting.value;
          return SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: busy
                    ? null
                    : const LinearGradient(
                        colors: AppColors.primaryGradient),
                color: busy
                    ? Colors.white.withValues(alpha: 0.08)
                    : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: busy ? null : logic.connectRelay,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white70),
                        ),
                      )
                    : const Text('连接中继',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        Text(
          '通过中继服务器连接，无需手机和电脑在同一网络',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.3)),
        ),
      ],
    );
  }
}

