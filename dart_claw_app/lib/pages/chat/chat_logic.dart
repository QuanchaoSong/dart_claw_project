import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChatLogic extends GetxController {
  final inputController = TextEditingController();
  final scrollController = ScrollController();

  final currentSessionTitle = 'New Chat'.obs;
  final isRunning = false.obs;

  // TODO: replace with proper message model list
  final messages = [].obs;

  @override
  void onClose() {
    inputController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  void submitInput() {
    final text = inputController.text.trim();
    if (text.isEmpty || isRunning.value) return;
    inputController.clear();
    // TODO: send task via WebSocket
  }

  void stopRunning() {
    // TODO: send stop signal via WebSocket
    isRunning.value = false;
  }

  void newSession() {
    currentSessionTitle.value = 'New Chat';
    messages.clear();
    // TODO: notify desktop via WebSocket
  }

  void switchToSession(String sessionId) {
    // TODO: load session from WebSocket / local cache
  }
}
