import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../others/services/connection_service.dart';
import '../chat/chat_page.dart';

class ConnectionLogic extends GetxController {
  final hostController = TextEditingController();
  final portController = TextEditingController(text: '7788');

  final isConnecting = false.obs;
  final errorMessage = RxnString();

  @override
  void onClose() {
    hostController.dispose();
    portController.dispose();
    super.onClose();
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
