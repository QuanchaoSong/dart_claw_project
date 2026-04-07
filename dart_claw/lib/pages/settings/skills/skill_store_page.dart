import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/pages/settings/skills/skill_store_list_view.dart';
import 'package:dart_claw/pages/settings/skills/skill_store_logic.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 从 Settings Skills footer 调用：openSkillStore(context)
void openSkillStore(BuildContext context) {
  Get.lazyPut<SkillStoreLogic>(() => SkillStoreLogic());
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'skill_store',
    barrierColor: Colors.black.withOpacity(0.6),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, _, __) => const _SkillStorePage(),
    transitionBuilder: (ctx, anim, _, child) {
      final curved =
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  ).whenComplete(() => Get.delete<SkillStoreLogic>());
}

class _SkillStorePage extends StatelessWidget {
  const _SkillStorePage();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 560,
        height: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D1230), AppColors.bgMid],
              ),
              border: Border(
                left:
                    BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: Navigator(
                    onGenerateRoute: (_) => MaterialPageRoute(
                      builder: (_) => const SkillStoreListView(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront_rounded,
              size: 16, color: AppColors.reasoningAccent),
          const SizedBox(width: 8),
          const Text(
            'Skill Store',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.close,
                  size: 16, color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}
