import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../others/constants/color_constants.dart';
import '../chat_logic.dart';

class InputAreaView extends StatelessWidget {
  InputAreaView({super.key});

  final logic = Get.find<ChatLogic>();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgDeep,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── Text field ──
            Expanded(
              child: TextField(
                controller: logic.inputController,
                maxLines: 5,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '发送任务给桌面端…',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // ── Send button ──
            Obx(() => GestureDetector(
                  onTap: logic.isRunning.value ? null : logic.submitInput,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: logic.isRunning.value
                          ? null
                          : const LinearGradient(
                              colors: AppColors.primaryGradient),
                      color: logic.isRunning.value
                          ? Colors.white.withOpacity(0.08)
                          : null,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      size: 20,
                      color: logic.isRunning.value
                          ? Colors.white30
                          : Colors.white,
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
