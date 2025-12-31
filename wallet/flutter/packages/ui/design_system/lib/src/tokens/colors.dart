import 'package:flutter/material.dart';

/// Brand colors and color tokens.
abstract final class AppColors {
  // === Brand Colors ===

  /// Primary brand color (green)
  static const Color brandPrimary = Color(0xFF49EACB);

  /// Secondary brand color (teal)
  static const Color brandSecondary = Color(0xFF1AA68D);

  /// Dark brand color (background)
  static const Color brandDark = Color(0xFF0D1117);

  // === Primary Palette (Green) ===

  static const Color primary = Color(0xFF49EACB);
  static const Color primaryLight = Color(0xFF7EFFD8);
  static const Color primaryDark = Color(0xFF1AA68D);
  static const Color onPrimary = Color(0xFF003829);
  static const Color primaryContainer = Color(0xFF005140);
  static const Color onPrimaryContainer = Color(0xFF7EFFD8);

  // === Secondary Palette ===

  static const Color secondary = Color(0xFF4DD0E1);
  static const Color secondaryLight = Color(0xFF88FFFF);
  static const Color secondaryDark = Color(0xFF009FAF);
  static const Color onSecondary = Color(0xFF00363D);
  static const Color secondaryContainer = Color(0xFF004F58);
  static const Color onSecondaryContainer = Color(0xFF97F0FF);

  // === Tertiary Palette ===

  static const Color tertiary = Color(0xFFB0BEC5);
  static const Color onTertiary = Color(0xFF1C313A);
  static const Color tertiaryContainer = Color(0xFF334955);
  static const Color onTertiaryContainer = Color(0xFFCFD8DC);

  // === Error Palette ===

  static const Color error = Color(0xFFFF6B6B);
  static const Color errorLight = Color(0xFFFF9E9E);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  // === Success Palette ===

  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFF81C784);
  static const Color onSuccess = Color(0xFF002200);

  // === Warning Palette ===

  static const Color warning = Color(0xFFFFB74D);
  static const Color warningLight = Color(0xFFFFE97D);
  static const Color onWarning = Color(0xFF412D00);

  // === Light Theme Surfaces ===

  static const Color surfaceLight = Color(0xFFF8FAF9);
  static const Color surfaceVariantLight = Color(0xFFDBE5E0);
  static const Color surfaceContainerLight = Color(0xFFECF0EE);
  static const Color surfaceContainerHighLight = Color(0xFFE1E6E3);
  static const Color backgroundLight = Color(0xFFFBFDFC);
  static const Color onSurfaceLight = Color(0xFF191C1B);
  static const Color onSurfaceVariantLight = Color(0xFF3F4945);
  static const Color outlineLight = Color(0xFF6F7975);
  static const Color outlineVariantLight = Color(0xFFBFC9C4);

  // === Dark Theme Surfaces ===

  static const Color surfaceDark = Color(0xFF0D1117);
  static const Color surfaceVariantDark = Color(0xFF1C2128);
  static const Color surfaceContainerDark = Color(0xFF161B22);
  static const Color surfaceContainerHighDark = Color(0xFF21262D);
  static const Color backgroundDark = Color(0xFF010409);
  static const Color onSurfaceDark = Color(0xFFE1E3E1);
  static const Color onSurfaceVariantDark = Color(0xFFBFC9C4);
  static const Color outlineDark = Color(0xFF89938E);
  static const Color outlineVariantDark = Color(0xFF3F4945);

  // === Semantic Colors ===

  static const Color incoming = Color(0xFF49EACB);
  static const Color outgoing = Color(0xFFFF6B6B);
  static const Color pending = Color(0xFFFFB74D);
  static const Color confirmed = Color(0xFF4CAF50);

  // === Utility ===

  static const Color transparent = Colors.transparent;
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color divider = Color(0x1F000000);
  static const Color dividerDark = Color(0x1FFFFFFF);
}
