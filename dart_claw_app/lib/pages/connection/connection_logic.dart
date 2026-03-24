import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../others/services/connection_service.dart';
import '../chat/chat_page.dart';

class ConnectionLogic extends GetxController {
  final hostController = TextEditingController(text: '127.0.0.1');
  final portController = TextEditingController(text: '37788');

  final isConnecting = false.obs;
  final errorMessage = RxnString();
  final showManual = false.obs;
  final scannerActive = true.obs;

  final scannerController = MobileScannerController();

  @override
  void onClose() {
    hostController.dispose();
    portController.dispose();
    scannerController.dispose();
    super.onClose();
  }

  void onDetect(BarcodeCapture capture) {
    if (!scannerActive.value) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    final uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'ws' && uri.scheme != 'http')) return;
    scannerActive.value = false;
    scannerController.stop();
    connectFromQr(raw);
  }

  void resetScanner() {
    scannerActive.value = true;
    scannerController.start();
  }

  Future<void> connectFromQr(String wsUrl) async {
    final uri = Uri.tryParse(wsUrl);
    if (uri == null || uri.host.isEmpty || uri.port == 0) return;
    hostController.text = uri.host;
    portController.text = '${uri.port}';
    await connect();
  }

  Future<void> connect() async {
    final host = hostController.text.trim();
    final port = int.tryParse(portController.text.trim());
    if (host.isEmpty || port == null) {
      errorMessage.value = '请填写有效的 IP 和端口';
      return;
    }
    isConnecting.value = true;
    errorMessage.value = null;
    try {
      final ok = await ConnectionService()
          .connect(host: host, port: port);
      if (ok) Get.off(() => ChatPage());
    } catch (e) {
      errorMessage.value = '连接失败: $e';
    } finally {
      isConnecting.value = false;
    }
  }
}
