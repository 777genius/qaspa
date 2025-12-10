import 'package:flutter/material.dart';

import 'light_theme.dart';
import 'dark_theme.dart';

/// Main app theme provider.
abstract final class AppTheme {
  /// Light theme
  static ThemeData get light => createLightTheme();

  /// Dark theme
  static ThemeData get dark => createDarkTheme();

  /// Get theme by brightness
  static ThemeData fromBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  /// Get current theme based on platform brightness
  static ThemeData system(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    return fromBrightness(brightness);
  }
}

/// Theme mode extension.
extension ThemeModeExtension on ThemeMode {
  /// Get theme data for this mode.
  ThemeData resolve(BuildContext context) {
    return switch (this) {
      ThemeMode.light => AppTheme.light,
      ThemeMode.dark => AppTheme.dark,
      ThemeMode.system => AppTheme.system(context),
    };
  }
}
