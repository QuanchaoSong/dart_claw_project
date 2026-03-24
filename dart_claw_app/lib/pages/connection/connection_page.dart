import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../others/constants/color_constants.dart';
import 'connection_logic.dart';

class ConnectionPage extends StatelessWidget {
  ConnectionPage({super.key});

  final logic = Get.put(ConnectionLogic());

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E1A), Color(0xFF0D1230), Color(0xFF111827)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Column(
              children: [
                _buildLogo(),
                const SizedBox(height: 32),
                _buildQrSection(logic),
                const SizedBox(height: 16),
                _buildManualToggle(logic),
                Obx(() {
                  if (!logic.showManual.value) return const SizedBox.shrink();
                  return Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildForm(logic),
                      const SizedBox(height: 16),
                      _buildConnectButton(logic),
                    ],
                  );
                }),
                Obx(() {
                  final msg = logic.errorMessage.value;
                  if (msg == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
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
        Text(
          'Dart Claw',
          style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        SizedBox(height: 4),
        Text(
          'Remote Control',
          style: TextStyle(fontSize: 13, color: Colors.white38),
        ),
      ],
    );
  }

  // ── QR scanner ───────────────────────────────────────────────────────────

  Widget _buildQrSection(ConnectionLogic logic) {
    return Column(
      children: [
        const Text(
          '扫描桌面端二维码连接',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          '在桌面端 Server 设置页面找到二维码',
          style:
              TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
        ),
        const SizedBox(height: 16),
        Obx(() {
          final busy = logic.isConnecting.value;
          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: double.infinity,
              height: 280,
              child: Stack(
                children: [
                  MobileScanner(
                    controller: logic.scannerController,
                    onDetect: logic.onDetect,
                  ),
                  Positioned.fill(
                    child: CustomPaint(painter: _QrFramePainter()),
                  ),
                  if (busy)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                            SizedBox(height: 16),
                            Text('正在连接…',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: logic.resetScanner,
          icon: const Icon(Icons.refresh_rounded,
              size: 16, color: Colors.white54),
          label: const Text('重新扫描',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
        ),
      ],
    );
  }

  // ── Manual toggle ─────────────────────────────────────────────────────────

  Widget _buildManualToggle(ConnectionLogic logic) {
    return Obx(() => GestureDetector(
          onTap: () => logic.showManual.toggle(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                logic.showManual.value ? '隐藏手动输入' : '手动输入 IP / 端口',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(width: 4),
              Icon(
                logic.showManual.value
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: Colors.white38,
                size: 18,
              ),
            ],
          ),
        ));
  }

  // ── Manual form ───────────────────────────────────────────────────────────

  Widget _buildForm(ConnectionLogic logic) {
    return Column(
      children: [
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
      ],
    );
  }

  // ── Connect button ────────────────────────────────────────────────────────

  Widget _buildConnectButton(ConnectionLogic logic) {
    return Obx(() {
      final busy = logic.isConnecting.value;
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: busy
                ? null
                : const LinearGradient(colors: AppColors.primaryGradient),
            color: busy ? Colors.white.withValues(alpha: 0.08) : null,
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
                      valueColor: AlwaysStoppedAnimation(Colors.white70),
                    ),
                  )
                : const Text(
                    '连接',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      );
    });
  }
}


// ── QR viewfinder corners ──────────────────────────────────────────────────

class _QrFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cornerLen = 28.0;
    const r = 6.0;
    const margin = 20.0;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final l = margin;
    final t = margin;
    final ri = size.width - margin;
    final b = size.height - margin;

    // top-left
    canvas.drawLine(Offset(l + r, t), Offset(l + cornerLen, t), paint);
    canvas.drawLine(Offset(l, t + r), Offset(l, t + cornerLen), paint);
    canvas.drawArc(Rect.fromLTWH(l, t, r * 2, r * 2), -3.14 / 2 * 2, 3.14 / 2 * (-1), false, paint);
    // top-right
    canvas.drawLine(Offset(ri - cornerLen, t), Offset(ri - r, t), paint);
    canvas.drawLine(Offset(ri, t + r), Offset(ri, t + cornerLen), paint);
    canvas.drawArc(Rect.fromLTWH(ri - r * 2, t, r * 2, r * 2), -3.14 / 2, 3.14 / 2 * (-1), false, paint);
    // bottom-left
    canvas.drawLine(Offset(l, b - cornerLen), Offset(l, b - r), paint);
    canvas.drawLine(Offset(l + r, b), Offset(l + cornerLen, b), paint);
    canvas.drawArc(Rect.fromLTWH(l, b - r * 2, r * 2, r * 2), 3.14 / 2, 3.14 / 2 * (-1), false, paint);
    // bottom-right
    canvas.drawLine(Offset(ri, b - cornerLen), Offset(ri, b - r), paint);
    canvas.drawLine(Offset(ri - cornerLen, b), Offset(ri - r, b), paint);
    canvas.drawArc(Rect.fromLTWH(ri - r * 2, b - r * 2, r * 2, r * 2), 0, 3.14 / 2 * (-1), false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

