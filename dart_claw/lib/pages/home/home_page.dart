import 'package:dart_claw/pages/home/home_logic.dart';
import 'package:dart_claw/pages/home/view/chat_area_view.dart';
import 'package:dart_claw/pages/home/view/session_info_and_settings_view.dart';
import 'package:dart_claw/pages/home/view/session_sidebar_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final logic = Get.put(HomeLogic());

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
        child: Row(
          children: [
            const SessionSidebarView(),
            const Expanded(child: ChatAreaView()),
            Obx(
              () => logic.showInfoPanel.value
                  ? const SessionInfoAndSettingsView()
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

