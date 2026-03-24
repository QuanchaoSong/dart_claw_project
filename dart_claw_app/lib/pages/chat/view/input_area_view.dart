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
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // ── AI 请求文件的提示条 ──
          Obx(() {
            final reqId = logic.pendingFileRequestId.value;
            if (reqId == null) return const SizedBox.shrink();
            return _FileRequestBanner(
              prompt: logic.pendingFileRequestPrompt.value,
              onPickFile: () => logic.pickAndUploadFileForRequest(reqId),
              onDismiss: logic.cancelFileRequest,
            );
          }),
          // ── 上传进度条（仅上传时可见）──
          Obx(() {
            if (!logic.isUploading.value) return const SizedBox.shrink();
            return _UploadProgressRow(
              fileName: logic.uploadFileName.value,
              progress: logic.uploadProgress.value,
            );
          }),
            // ── 输入行 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                      style:
                          const TextStyle(color: Colors.white, fontSize: 14),
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
                          borderSide:
                              const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // ── 发送按钮 ──
                  Obx(() => GestureDetector(
                        onTap:
                            logic.isRunning.value ? null : logic.submitInput,
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
          ],
        ),
      ),
    );
  }
}
// ── AI 请求文件提示条 ─────────────────────────────────────────────────────────────────────

class _FileRequestBanner extends StatelessWidget {
  const _FileRequestBanner({
    required this.prompt,
    required this.onPickFile,
    required this.onDismiss,
  });

  final String prompt;
  final VoidCallback onPickFile;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: Colors.amber.withOpacity(0.12),
      child: Row(
        children: [
          const Icon(Icons.upload_file_rounded, size: 18, color: Colors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              prompt,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onPickFile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: const Text('选择文件',
                  style: TextStyle(fontSize: 12, color: Colors.amber)),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded, size: 18, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}
// ── 上传进度行 ────────────────────────────────────────────────────────────────

class _UploadProgressRow extends StatelessWidget {
  const _UploadProgressRow({
    required this.fileName,
    required this.progress,
  });

  final String fileName;
  final double progress; // 0.0 ~ 1.0

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white.withOpacity(0.04),
      child: Row(
        children: [
          const Icon(Icons.upload_rounded, size: 16, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(
                    progress >= 1.0 ? Colors.greenAccent : Colors.amber,
                  ),
                  minHeight: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            progress >= 1.0 ? '完成' : '${(progress * 100).toInt()}%',
            style: TextStyle(
              fontSize: 11,
              color: progress >= 1.0 ? Colors.greenAccent : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}
