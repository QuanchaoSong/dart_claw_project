import 'package:flutter/material.dart';

/// dart_claw 全局色板
///
/// 主色系：青绿（Teal）
/// 调整主色只需改 [AppColors.primary] 和 [AppColors.secondary]，
/// 其余 tint / gradient 同步跟随。
abstract final class AppColors {
  // ─── 背景 ──────────────────────────────────────────────────────────────────

  /// 最深背景（Scaffold / 全屏渐变起点）
  static const bgDeep = Color(0xFF060F0E);

  /// 中层背景（侧边栏、面板）
  static const bgMid = Color(0xFF0D1F1D);

  /// 浅层背景（聊天区）
  static const bgSurface = Color(0xFF0A1917);

  // ─── 主色 ──────────────────────────────────────────────────────────────────

  /// 主色：Teal 600
  static const primary = Color(0xFF0D9488);

  /// 辅色：Teal 400（渐变终点、高亮）
  static const secondary = Color(0xFF14B8A6);

  // ─── 派生 ─────────────────────────────────────────────────────────────────

  /// 主色渐变（按钮、用户气泡等）
  static const primaryGradient = [primary, secondary];

  /// Reasoning 区块标注色（比主色更亮的 Teal 300）
  static const reasoningAccent = Color(0xFF2DD4BF);

  // ─── 停止按钮（运行中）────────────────────────────────────────────────────

  static const stopBgStart = Color(0xFF1A1212);
  static const stopBgEnd   = Color(0xFF2A1414);

  // ─── 弹窗 / 对话框 ────────────────────────────────────────────────────────

  static const dialogBg = Color(0xFF0D1F1D);

  // ─── Confirm 按钮主色（Allow）─────────────────────────────────────────────
  // 复用 primary，保持一致
  static const confirmAllow = primary;
}
