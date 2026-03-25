import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../others/services/connection_service.dart';
import '../chat/chat_page.dart';

class ConnectionLogic extends GetxController {
  final hostController = TextEditingController(text: '127.0.0.1');
  final portController = TextEditingController(text: '37788');
  final codeController = TextEditingController();

  final isConnecting = false.obs;
  final errorMessage = RxnString();
  final selectedTab = 0.obs; // 0 = scan, 1 = manual

  @override
  void onClose() {
    hostController.dispose();
    portController.dispose();
    codeController.dispose();
    super.onClose();
  }

  Future<void> connectFromQr(String wsUrl) async {
    final uri = Uri.tryParse(wsUrl);
    if (uri == null || uri.host.isEmpty || uri.port == 0) return;
    hostController.text = uri.host;
    portController.text = '${uri.port}';
    codeController.text = uri.queryParameters['code'] ?? '';
    await connect();
  }

  Future<void> connect() async {
    final host = hostController.text.trim();
    final port = int.tryParse(portController.text.trim());
    if (host.isEmpty || port == null) {
      errorMessage.value = '请填写有效的 IP 和端口';
      return;
    }
    final code = codeController.text.trim();
    isConnecting.value = true;
    errorMessage.value = null;
    try {
      final ok = await ConnectionService()
          .connect(host: host, port: port, code: code);
      if (ok) Get.off(() => ChatPage());
    } catch (e) {
      errorMessage.value = '连接失败: $e';
    } finally {
      isConnecting.value = false;
    }
  }
}
