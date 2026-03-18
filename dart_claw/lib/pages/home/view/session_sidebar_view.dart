import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/others/model/claw_session_info.dart';
import 'package:dart_claw/pages/home/home_logic.dart';
import 'package:dart_claw/pages/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ─── 侧边栏主体 ───────────────────────────────────────────────────────────────

class SessionSidebarView extends StatelessWidget {
  const SessionSidebarView({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.find<HomeLogic>();
    return Container(
      width: 260,
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            children: [
              _buildHeader(),
              const Divider(color: Colors.white12, height: 1),
              Expanded(child: _buildSessionList(context, logic)),
              const Divider(color: Colors.white12, height: 1),
              _buildFooter(context, logic),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '🦞 dart Claw',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSessionList(BuildContext context, HomeLogic logic) {
    return Obx(() {
      final sessions = logic.sessions;
      if (sessions.isEmpty) {
        return const Center(
          child: Text(
            'No sessions yet',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: sessions.length,
        itemBuilder: (ctx, i) {
          final session = sessions[i];
          return Obx(() {
            final isActive = logic.currentSessionId.value == session.id;
            return _SessionItem(
              session: session,
              isActive: isActive,
              onTap: () => logic.switchToSession(session.id),
              onRename: () => _showRenameDialog(logic, session),
              onDelete: () => _showDeleteConfirm(logic, session),
            );
          });
        },
      );
    });
  }

  Widget _buildFooter(BuildContext context, HomeLogic logic) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: _FooterButton(
              icon: Icons.add,
              label: 'New',
              onTap: logic.newSession,
            ),
          ),
          const SizedBox(width: 8),
          _FooterIconButton(
            icon: Icons.settings_outlined,
            onTap: () => openSettings(context),
          ),
        ],
      ),
    );
  }

  // ─── 弹窗 ────────────────────────────────────────────────────────────────

  void _showRenameDialog(HomeLogic logic, ClawSessionInfo session) {
    final ctrl = TextEditingController(text: session.title);
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: const Text(
          'Rename Session',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Session title',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: AppColors.secondary),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onSubmitted: (_) => _doRename(logic, session, ctrl),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => _doRename(logic, session, ctrl),
            child: const Text('Rename',
                style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    );
  }

  void _doRename(HomeLogic logic, ClawSessionInfo session, TextEditingController ctrl) {
    final t = ctrl.text.trim();
    if (t.isNotEmpty) logic.renameSession(session.id, t);
    Get.back();
  }

  void _showDeleteConfirm(HomeLogic logic, ClawSessionInfo session) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: const Text(
          'Delete Session',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          'Delete "${session.title}"?\nThis cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              logic.deleteSessionById(session.id);
            },
            child: Text('Delete',
                style: TextStyle(color: Colors.red.shade300)),
          ),
        ],
      ),
    );
  }
}

// ─── Session 列表项 ───────────────────────────────────────────────────────────

class _SessionItem extends StatelessWidget {
  const _SessionItem({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final ClawSessionInfo session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // macOS 右键菜单
      onSecondaryTapUp: (d) => _showContextMenu(context, d.globalPosition),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: InkWell(
          onTap: onTap,
          onLongPress: () {
            final box = context.findRenderObject() as RenderBox?;
            final pos = box?.localToGlobal(
                  Offset(box.size.width / 2, box.size.height / 2)) ??
                Offset.zero;
            _showContextMenu(context, pos);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isActive
                  ? Border.all(
                      color: AppColors.primary.withOpacity(0.35), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white70,
                          fontSize: 13,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(session.updatedAt),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset globalPos) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        globalPos.dx + 1,
        globalPos.dy + 1,
      ),
      color: AppColors.bgMid,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      items: [
        const PopupMenuItem(
          value: 'rename',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 14, color: Colors.white70),
              SizedBox(width: 8),
              Text('Rename',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.delete_outline,
                  size: 14, color: Colors.red.shade300),
              const SizedBox(width: 8),
              Text('Delete',
                  style: TextStyle(
                      color: Colors.red.shade300, fontSize: 13)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'rename') onRename();
      if (value == 'delete') onDelete();
    });
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }
}

// ─── 底栏按钮 ─────────────────────────────────────────────────────────────────

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: Colors.white70),
            const SizedBox(width: 6),
            Text(label,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _FooterIconButton extends StatelessWidget {
  const _FooterIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Icon(icon, size: 16, color: Colors.white70),
      ),
    );
  }
}
