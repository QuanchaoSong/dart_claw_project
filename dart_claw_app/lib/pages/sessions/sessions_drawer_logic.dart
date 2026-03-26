import 'package:dart_claw_app/others/tool/global_tool.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../chat/chat_logic.dart';

class SessionsDrawerLogic extends GetxController {
  ChatLogic get _chat => Get.find<ChatLogic>();

  List get sessions => _chat.sessions;

  @override
  void onReady() {
    super.onReady();

    hideKeyboard(Get.context!);
  }

  void newSession() => _chat.newSession();

  void switchToSession(dynamic session) => _chat.switchToSession(session);

  void deleteSession(dynamic session) => _chat.deleteSession(session);
}
