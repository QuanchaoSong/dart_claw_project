import 'package:dart_claw/pages/home/home_logic.dart';
import 'package:dart_claw/pages/settings/view/common_settings_widgets.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Settings → Remote 分区
/// 管理与移动端远程控制相关的持久化设置（不在 session 级别，而是全局配置）。
class SettingsRemoteView extends StatelessWidget {
  const SettingsRemoteView({super.key});

  @override
  Widget build(BuildContext context) {
    final homeLogic = Get.find<HomeLogic>();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        settingsSectionTitle('File Transfer'),
        const SizedBox(height: 8),
        const Text(
          '手机端上传的文件保存目录（支持 ~/... 路径）',
          style: TextStyle(fontSize: 12, color: Colors.white38),
        ),
        const SizedBox(height: 12),
        Obx(() => _DirPickerRow(
              path: homeLogic.uploadSaveDir.value,
              onPick: () async {
                final dir = await getDirectoryPath();
                if (dir != null) homeLogic.setUploadSaveDir(dir);
              },
            )),
        const SizedBox(height: 6),
        const Text(
          '修改后立即生效，无需保存。',
          style: TextStyle(fontSize: 11, color: Colors.white24),
        ),
      ],
    );
  }
}

// ── 目录选择行 ──────────────────────────────────────────────────────────────

class _DirPickerRow extends StatelessWidget {
  const _DirPickerRow({required this.path, required this.onPick});

  final String path;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_outlined, size: 16, color: Colors.white38),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              path,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onPick,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(6),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Text(
                '浏览',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
