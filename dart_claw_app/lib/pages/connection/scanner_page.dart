import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'scanner_logic.dart';

/// 全屏相机扫描页面（模糊蒙版 + 中央清晰扫描区）
class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(ScannerLogic());
    final media = MediaQuery.of(context);
    final scanSize = media.size.width * 0.65;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          MobileScanner(
            controller: logic.scannerController,
            onDetect: logic.onDetect,
            errorBuilder: (context, error) {
              logic.onScanError(error);
              return const SizedBox.expand();
            },
          ),

          // Blur overlay (only when camera works)
          Obx(() => logic.hasError.value
              ? const SizedBox.shrink()
              : _ScanOverlay(scanSize: scanSize)),

          // Error fallback
          Obx(() {
            if (!logic.hasError.value) return const SizedBox.shrink();
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography_outlined,
                        color: Colors.white38, size: 64),
                    const SizedBox(height: 20),
                    Obx(() => Text(
                          logic.errorMsg.value,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 14),
                        )),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('返回手动输入',
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
            );
          }),

          // Close button
          Positioned(
            top: media.padding.top + 8,
            left: 8,
            child: IconButton(
              onPressed: () => Get.back(),
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 28),
            ),
          ),

          // Hint text
          Obx(() => logic.hasError.value
              ? const SizedBox.shrink()
              : Positioned(
                  left: 0,
                  right: 0,
                  top: (media.size.height + scanSize) / 2 + 36,
                  child: const Text(
                    '将二维码放入框内',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w500),
                  ),
                )),
        ],
      ),
    );
  }
}

// ── 模糊蒙版 + 中央透明扫描区 ──────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay({required this.scanSize});
  final double scanSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final rect = Rect.fromCenter(
        center:
            Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
        width: scanSize,
        height: scanSize,
      );
      return Stack(
        children: [
          ClipPath(
            clipper: _InvertedRRectClipper(rect),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                  color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
          CustomPaint(
            painter: _CornerPainter(rect),
            size: Size(constraints.maxWidth, constraints.maxHeight),
          ),
        ],
      );
    });
  }
}

class _InvertedRRectClipper extends CustomClipper<Path> {
  final Rect rect;
  _InvertedRRectClipper(this.rect);

  @override
  Path getClip(Size size) {
    return Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(covariant _InvertedRRectClipper old) =>
      old.rect != rect;
}

class _CornerPainter extends CustomPainter {
  final Rect rect;
  _CornerPainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    const len = 24.0;
    const r = 16.0;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final l = rect.left;
    final t = rect.top;
    final ri = rect.right;
    final b = rect.bottom;

    // top-left
    canvas.drawLine(Offset(l + r, t), Offset(l + r + len, t), paint);
    canvas.drawLine(Offset(l, t + r), Offset(l, t + r + len), paint);
    canvas.drawArc(
        Rect.fromLTWH(l, t, r * 2, r * 2), pi, pi / 2, false, paint);
    // top-right
    canvas.drawLine(Offset(ri - r - len, t), Offset(ri - r, t), paint);
    canvas.drawLine(Offset(ri, t + r), Offset(ri, t + r + len), paint);
    canvas.drawArc(Rect.fromLTWH(ri - r * 2, t, r * 2, r * 2), -pi / 2,
        pi / 2, false, paint);
    // bottom-left
    canvas.drawLine(Offset(l, b - r - len), Offset(l, b - r), paint);
    canvas.drawLine(Offset(l + r, b), Offset(l + r + len, b), paint);
    canvas.drawArc(Rect.fromLTWH(l, b - r * 2, r * 2, r * 2), pi / 2,
        pi / 2, false, paint);
    // bottom-right
    canvas.drawLine(Offset(ri, b - r - len), Offset(ri, b - r), paint);
    canvas.drawLine(Offset(ri - r - len, b), Offset(ri - r, b), paint);
    canvas.drawArc(
        Rect.fromLTWH(ri - r * 2, b - r * 2, r * 2, r * 2), 0, pi / 2,
        false, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => old.rect != rect;
}
