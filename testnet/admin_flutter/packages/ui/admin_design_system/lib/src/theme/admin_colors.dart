import 'package:flutter/material.dart';

abstract final class AdminColors {
  // Primary palette
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);

  // Secondary palette
  static const Color secondary = Color(0xFF10B981);
  static const Color secondaryLight = Color(0xFF34D399);
  static const Color secondaryDark = Color(0xFF059669);

  // Status colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Node status colors
  static const Color running = Color(0xFF22C55E);
  static const Color starting = Color(0xFFF59E0B);
  static const Color stopped = Color(0xFF6B7280);
  static const Color failed = Color(0xFFEF4444);
  static const Color syncing = Color(0xFF3B82F6);

  // Background colors - Light
  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);

  // Background colors - Dark
  static const Color backgroundDark = Color(0xFF111827);
  static const Color surfaceDark = Color(0xFF1F2937);
  static const Color cardDark = Color(0xFF374151);

  // Text colors - Light
  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textTertiaryLight = Color(0xFF9CA3AF);

  // Text colors - Dark
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  static const Color textTertiaryDark = Color(0xFF6B7280);

  // Border colors
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF374151);

  // Sidebar colors
  static const Color sidebarLight = Color(0xFFF3F4F6);
  static const Color sidebarDark = Color(0xFF1F2937);
  static const Color sidebarActiveLight = Color(0xFFE0E7FF);
  static const Color sidebarActiveDark = Color(0xFF312E81);
}
