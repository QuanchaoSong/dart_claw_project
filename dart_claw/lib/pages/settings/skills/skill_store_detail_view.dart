import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/pages/settings/skills/skill_store_logic.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Skill Store 详情页（在弹窗的 Navigator 内 push 进来）
class SkillStoreDetailView extends StatelessWidget {
  const SkillStoreDetailView({
    super.key,
    required this.itemId,
    required this.itemName,
  });

  final String itemId;
  final String itemName;

  @override
  Widget build(BuildContext context) {
    final logic = Get.find<SkillStoreLogic>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D1230), AppColors.bgMid],
          ),
        ),
        child: Column(
          children: [
            _buildHeader(context, logic),
            Expanded(child: _buildBody(logic)),
          ],
        ),
      ),
    );
  }

  // ─── 顶部导航栏 ────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, SkillStoreLogic logic) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 14, color: Colors.white54),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              itemName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 下载按钮
          Obx(() {
            final detail = logic.detail.value;
            final isDownloading = logic.downloadingIds.contains(itemId);
            if (detail == null) return const SizedBox.shrink();
            return GestureDetector(
              onTap: isDownloading
                  ? null
                  : () => logic.downloadSkill(
                      itemId, detail.name, detail.version),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isDownloading
                      ? null
                      : const LinearGradient(
                          colors: AppColors.primaryGradient),
                  color: isDownloading
                      ? Colors.white.withOpacity(0.08)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isDownloading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white54),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.download_rounded,
                              size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            '下载',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── 详情内容 ──────────────────────────────────────────────────────────────

  Widget _buildBody(SkillStoreLogic logic) {
    return Obx(() {
      if (logic.isDetailLoading.value) {
        return const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white38),
        );
      }

      if (logic.detailErrorMsg.value.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 36, color: Colors.white24),
              const SizedBox(height: 12),
              Text(
                logic.detailErrorMsg.value,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => logic.loadDetail(itemId),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Text('重试',
                      style: TextStyle(
                          color: Colors.white60, fontSize: 13)),
                ),
              ),
            ],
          ),
        );
      }

      final detail = logic.detail.value;
      if (detail == null) return const SizedBox.shrink();

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 元信息行
            _MetaRow(detail: detail),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),

            // 参数
            if (detail.parameters.isNotEmpty) ...[
              _SectionLabel('参数'),
              const SizedBox(height: 8),
              ...detail.parameters.map((p) => _ParamRow(param: p)),
              const SizedBox(height: 16),
            ],

            // 描述 / 正文
            if (detail.description.isNotEmpty) ...[
              _SectionLabel('描述'),
              const SizedBox(height: 8),
              Text(
                detail.description,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
            ],

            // markdown 正文预览（纯文本，不渲染）
            if (detail.content.isNotEmpty) ...[
              _SectionLabel('内容预览'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Text(
                  detail.content,
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.6,
                      fontFamily: 'monospace'),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

// ─── 小组件 ────────────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.detail});

  final dynamic detail; // SkillStoreDetailInfo

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _MetaBadge(
            Icons.person_outline_rounded, detail.authorName ?? ''),
        _MetaBadge(Icons.tag_rounded, 'v${detail.version}'),
        _MetaBadge(Icons.download_rounded, '${detail.downloads} 次下载'),
        ...((detail.tags as List<String>).map(
          (t) => Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
              border:
                  Border.all(color: AppColors.primary.withOpacity(0.25)),
            ),
            child: Text(t,
                style: const TextStyle(
                    color: AppColors.reasoningAccent, fontSize: 11)),
          ),
        )),
      ],
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white38),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _ParamRow extends StatelessWidget {
  const _ParamRow({required this.param});

  final dynamic param; // SkillStoreParameterInfo

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border:
                  Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Text(
              param.name as String,
              style: const TextStyle(
                  color: Colors.lightBlueAccent,
                  fontSize: 11,
                  fontFamily: 'monospace'),
            ),
          ),
          if (param.required as bool)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('*',
                  style:
                      TextStyle(color: Colors.orange, fontSize: 11)),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              param.description as String,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
