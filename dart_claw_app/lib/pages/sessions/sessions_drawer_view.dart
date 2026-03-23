import 'package:flutter/material.dart';
import '../../others/constants/color_constants.dart';
import '../chat/chat_logic.dart';
import '../settings/settings_page.dart';
import 'package:get/get.dart';

class SessionsDrawerView extends StatelessWidget {
  const SessionsDrawerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.bgMid,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const Divider(color: Colors.white12, height: 1),
            _buildNewChatButton(context),
            const Divider(color: Colors.white12, height: 1),
            Expanded(child: _buildSessionList(context)),
          ],
        ),
      ),
    );
  }

  // ── Header: app name + settings gear ──────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      child: Row(
        children: [
          const Text(
            '🦞 Dart Claw',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: Colors.white54, size: 20),
            tooltip: '设置',
            onPressed: () {
              // Close drawer first, then slide in settings from the right.
              Navigator.of(context).pop();
              openSettings(context);
            },
          ),
        ],
      ),
    );
  }

  // ── New chat button ────────────────────────────────────────────────────────

  Widget _buildNewChatButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('新对话'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.secondary,
            side: BorderSide(color: AppColors.secondary.withOpacity(0.4)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            Get.find<ChatLogic>().newSession();
          },
        ),
      ),
    );
  }

  // ── Session list ──────────────────────────────────────────────────────────

  Widget _buildSessionList(BuildContext context) {
    final logic = Get.find<ChatLogic>();
    return Obx(() {
      final sessions = logic.sessions;
      if (sessions.isEmpty) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline, color: Colors.white12, size: 36),
              SizedBox(height: 12),
              Text(
                '暂无会话',
                style: TextStyle(color: Colors.white24, fontSize: 13),
              ),
            ],
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        itemCount: sessions.length,
        itemBuilder: (ctx, i) {
          final session = sessions[i];
          return Dismissible(
            key: ValueKey(session.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade800,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline,
                  color: Colors.white, size: 20),
            ),
            onDismissed: (_) => logic.deleteSession(session),
            child: SessionListItem(
              title: session.title,
              updatedAt: session.updatedAt,
              isActive: false,
              onTap: () {
                Navigator.of(context).pop();
                logic.switchToSession(session);
              },
            ),
          );
        },
      );
    });
  }
}

// ─── Session list item (used once sessions come from WS) ──────────────────────

class SessionListItem extends StatelessWidget {
  const SessionListItem({
    super.key,
    required this.title,
    required this.updatedAt,
    required this.isActive,
    required this.onTap,
  });

  final String title;
  final DateTime updatedAt;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      selected: isActive,
      selectedTileColor: AppColors.primary.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: isActive ? Colors.white : Colors.white70,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _formatTime(updatedAt),
        style: const TextStyle(fontSize: 11, color: Colors.white30),
      ),
      onTap: onTap,
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${dt.month}/${dt.day}';
  }
}
