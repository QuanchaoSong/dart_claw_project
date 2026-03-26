import 'package:flutter/material.dart';
import '../../../others/constants/color_constants.dart';

class SessionListItemView extends StatelessWidget {
  const SessionListItemView({
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
