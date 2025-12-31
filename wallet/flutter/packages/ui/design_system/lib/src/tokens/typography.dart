import 'package:flutter/material.dart';

/// Typography tokens for the app.
///
/// Uses system fonts by default. Projects can customize fonts
/// by applying their own TextTheme via ThemeData or using
/// google_fonts package to wrap these styles.
///
/// Example with google_fonts:
/// ```dart
/// final customTheme = AppTypography.textTheme.apply(
///   fontFamily: GoogleFonts.inter().fontFamily,
/// );
/// ```
abstract final class AppTypography {
  /// Base text theme using system fonts.
  ///
  /// Follows Material 3 type scale.
  static TextTheme get textTheme {
    return const TextTheme(
      // Display
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        height: 1.12,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.16,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.22,
      ),
      // Headline
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.29,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.33,
      ),
      // Title
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.27,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        height: 1.5,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.43,
      ),
      // Body
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.43,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.33,
      ),
      // Label
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.43,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.33,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.45,
      ),
    );
  }

  /// Monospace font for addresses, amounts, and code.
  ///
  /// Uses system monospace font. Override with custom font:
  /// ```dart
  /// AppTypography.mono.copyWith(
  ///   fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
  /// )
  /// ```
  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  /// Large monospace for balance display.
  static const TextStyle monoLarge = TextStyle(
    fontFamily: 'monospace',
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );

  /// Small monospace for transaction IDs.
  static const TextStyle monoSmall = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
}
