import 'dart:io';
import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/others/network/skill_http_digger.dart';
import 'package:dart_claw/pages/settings/skills/model/skill_store_detail_info.dart';
import 'package:dart_claw/pages/settings/skills/model/skill_store_item_info.dart';
import 'package:dart_claw/pages/settings/skills/settings_skills_logic.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SkillStoreLogic extends GetxController {
  // ─── 搜索状态 ──────────────────────────────────────────────────────────────
  final searchQuery = ''.obs;
  final selectedTag = ''.obs;
  final sortBy = 'downloads'.obs; // downloads | recent | name

  final items = <SkillStoreItemInfo>[].obs;
  final isLoading = false.obs;
  final errorMsg = ''.obs;

  // 分页
  int _page = 1;
  static const int _pageSize = 20;
  final hasMore = true.obs;
  final isLoadingMore = false.obs;

  // ─── 详情状态 ──────────────────────────────────────────────────────────────
  final detail = Rxn<SkillStoreDetailInfo>();
  final isDetailLoading = false.obs;
  final detailErrorMsg = ''.obs;

  // ─── 下载状态（itemId -> true/false）──────────────────────────────────────
  final downloadingIds = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    // 不自动搜索，等用户主动触发
  }

  // ─── 搜索（重置页码）────────────────────────────────────────────────────────
  Future<void> search() async {
    if (searchQuery.value.trim().isEmpty && selectedTag.value.isEmpty) return;
    _page = 1;
    hasMore.value = true;
    items.clear();
    await _fetchPage(replace: true);
  }

  // ─── 加载更多 ───────────────────────────────────────────────────────────────
  Future<void> loadMore() async {
    if (!hasMore.value || isLoadingMore.value) return;
    _page++;
    await _fetchPage(replace: false);
  }

  Future<void> _fetchPage({required bool replace}) async {
    if (replace) {
      isLoading.value = true;
      errorMsg.value = '';
    } else {
      isLoadingMore.value = true;
    }

    try {
      final params = <String, String>{
        'page': '$_page',
        'page_size': '$_pageSize',
        'sort': sortBy.value,
      };
      if (searchQuery.value.isNotEmpty) params['q'] = searchQuery.value;
      if (selectedTag.value.isNotEmpty) params['tag'] = selectedTag.value;

      final resp = await SkillHttpDigger.shared.getJson(
        '/skill/search',
        queryParams: params,
      );

      if (!resp.isSuccess) {
        errorMsg.value = resp.message.isNotEmpty ? resp.message : '请求失败';
        return;
      }

      final rawItems =
          (resp.data!['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final fetched =
          rawItems.map((j) => SkillStoreItemInfo.fromJson(j)).toList();

      if (replace) {
        items.assignAll(fetched);
      } else {
        items.addAll(fetched);
      }

      final total = resp.data!['total'] as int? ?? 0;
      hasMore.value = items.length < total;
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  // ─── 查看详情 ───────────────────────────────────────────────────────────────
  Future<void> loadDetail(String id) async {
    detail.value = null;
    detailErrorMsg.value = '';
    isDetailLoading.value = true;

    try {
      final resp = await SkillHttpDigger.shared.getJson(
        '/skill/detail',
        queryParams: {'id': id},
      );

      if (!resp.isSuccess) {
        detailErrorMsg.value =
            resp.message.isNotEmpty ? resp.message : '加载详情失败';
        return;
      }

      detail.value = SkillStoreDetailInfo.fromJson(resp.data!);
    } finally {
      isDetailLoading.value = false;
    }
  }

  // ─── 下载 Skill ─────────────────────────────────────────────────────────────
  Future<void> downloadSkill(String id, String name, String version) async {
    if (downloadingIds.contains(id)) return;

    // 版本去重：本地已有同名同版本则跳过
    final skillsDir =
        Directory('${Platform.environment['HOME']}/.dart_claw/skills');
    final localFile = File('${skillsDir.path}/$name.md');
    if (await localFile.exists()) {
      final content = await localFile.readAsString();
      final versionMatch = RegExp(r'^version:\s*(.+)$', multiLine: true)
          .firstMatch(content);
      final localVersion = versionMatch?.group(1)?.trim() ?? '';
      if (localVersion == version) {
        Get.snackbar(
          '已是最新版本',
          '$name v$version 已安装，无需重复下载',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.dialogBg,
          colorText: Colors.white70,
        );
        return;
      }
    }

    downloadingIds.add(id);
    try {
      final resp = await SkillHttpDigger.shared.getRaw(
        '/skill/download',
        queryParams: {'id': id},
      );

      if (!resp.isSuccess) {
        Get.snackbar(
          '下载失败',
          resp.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.dialogBg,
          colorText: Colors.redAccent,
        );
        return;
      }

      await skillsDir.create(recursive: true);
      await localFile.writeAsString(resp.body!);

      // 下载成功后刷新已安装列表
      if (Get.isRegistered<SettingsSkillsLogic>()) {
        Get.find<SettingsSkillsLogic>().loadSkills();
      }

      Get.snackbar(
        'Skill 已下载',
        '$name.md 已保存至 Skills 目录',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.dialogBg,
        colorText: Colors.white70,
      );
    } finally {
      downloadingIds.remove(id);
    }
  }

  // ─── 可用标签 ───────────────────────────────────────────────────────────────
  static const List<String> availableTags = [
    'AI',
    'DevTools',
    'Network',
    'Files',
    'System',
    'Data',
    'Media',
    'Security',
    'Automation',
    'Other',
  ];
}
