import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/pages/settings/skills/model/skill_store_item_info.dart';
import 'package:dart_claw/pages/settings/skills/skill_store_detail_view.dart';
import 'package:dart_claw/pages/settings/skills/skill_store_logic.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Skill Store 搜索列表页（在弹窗的 Navigator 内作为第一个路由）
class SkillStoreListView extends StatefulWidget {
  const SkillStoreListView({super.key});

  @override
  State<SkillStoreListView> createState() => _SkillStoreListViewState();
}

class _SkillStoreListViewState extends State<SkillStoreListView> {
  late final SkillStoreLogic _logic;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _logic = Get.find<SkillStoreLogic>();
    _searchController.text = _logic.searchQuery.value;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _logic.loadMore();
    }
  }

  void _triggerSearch() {
    _logic.searchQuery.value = _searchController.text.trim();
    _logic.search();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchBar(),
        _buildTagBar(),
        Expanded(child: _buildList()),
      ],
    );
  }

  // ─── 搜索栏 ────────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: '搜索 Skill 名称或描述…',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 16, color: Colors.white38),
                  border: InputBorder.none,
                  // isDense + contentPadding 修复文字偏下问题
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
                onSubmitted: (_) => _triggerSearch(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 搜索按钮：输入为空时置灰
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (_, value, __) {
              final canSearch = value.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: canSearch ? _triggerSearch : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: canSearch
                        ? const LinearGradient(
                            colors: AppColors.primaryGradient)
                        : null,
                    color: canSearch
                        ? null
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '搜索',
                    style: TextStyle(
                        color: canSearch ? Colors.white : Colors.white24,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          _SortButton(logic: _logic, onChanged: _logic.search),
        ],
      ),
    );
  }

  // ─── 标签筛选栏 ────────────────────────────────────────────────────────────

  Widget _buildTagBar() {
    return Obx(() {
      return SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            _TagChip(
              label: '全部',
              isActive: _logic.selectedTag.value.isEmpty,
              onTap: () {
                _logic.selectedTag.value = '';
              },
            ),
            ...SkillStoreLogic.availableTags.map((tag) => _TagChip(
                  label: tag,
                  isActive: _logic.selectedTag.value == tag,
                  onTap: () {
                    _logic.selectedTag.value = tag;
                  },
                )),
          ],
        ),
      );
    });
  }

  // ─── 列表 ──────────────────────────────────────────────────────────────────

  Widget _buildList() {
    return Obx(() {
      if (_logic.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white38),
        );
      }

      if (_logic.errorMsg.value.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 36, color: Colors.white24),
              const SizedBox(height: 12),
              Text(
                _logic.errorMsg.value,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _OutlineButton(
                label: '重试',
                onTap: _logic.search,
              ),
            ],
          ),
        );
      }

      if (_logic.items.isEmpty) {
        return const Center(
          child: Text(
            '没有找到相关 Skill',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        );
      }

      return ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        itemCount:
            _logic.items.length + (_logic.hasMore.value ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          if (i == _logic.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white24),
              ),
            );
          }
          return _StoreItemCard(
            item: _logic.items[i],
            onTap: () => _openDetail(_logic.items[i]),
          );
        },
      );
    });
  }

  void _openDetail(SkillStoreItemInfo item) {
    _logic.loadDetail(item.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SkillStoreDetailView(itemId: item.id, itemName: item.name),
      ),
    );
  }
}

// ─── 列表卡片 ─────────────────────────────────────────────────────────────────

class _StoreItemCard extends StatelessWidget {
  const _StoreItemCard({required this.item, required this.onTap});

  final SkillStoreItemInfo item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.download_rounded,
                    size: 13, color: Colors.white38),
                const SizedBox(width: 3),
                Text(
                  '${item.downloads}',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.description,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: item.tags
                    .map((t) => _TagLabel(t))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── 小组件 ────────────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  const _TagChip(
      {required this.label,
      required this.isActive,
      required this.onTap});

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withOpacity(0.2)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withOpacity(0.5)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.reasoningAccent : Colors.white38,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _TagLabel extends StatelessWidget {
  const _TagLabel(this.tag);

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Text(
        tag,
        style: const TextStyle(
            color: AppColors.reasoningAccent, fontSize: 10),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.logic, required this.onChanged});

  final SkillStoreLogic logic;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = logic.sortBy.value;
      const options = {
        'downloads': '最多下载',
        'recent': '最近更新',
        'name': '字母序',
      };
      return PopupMenuButton<String>(
        color: const Color(0xFF1A2E2C),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onSelected: (v) {
          logic.sortBy.value = v;
          onChanged();
        },
        itemBuilder: (_) => options.entries
            .map((e) => PopupMenuItem(
                  value: e.key,
                  child: Text(e.value,
                      style: TextStyle(
                          color: e.key == current
                              ? AppColors.reasoningAccent
                              : Colors.white70,
                          fontSize: 13)),
                ))
            .toList(),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              const Icon(Icons.sort_rounded,
                  size: 14, color: Colors.white54),
              const SizedBox(width: 4),
              Text(
                options[current] ?? '排序',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(label,
            style:
                const TextStyle(color: Colors.white60, fontSize: 13)),
      ),
    );
  }
}
