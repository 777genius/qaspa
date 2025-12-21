import 'package:flutter/material.dart';

class ThemeStore extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  void toggleTheme(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (_themeMode == ThemeMode.system) {
      // If system, switch to opposite of current
      _themeMode = brightness == Brightness.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    } else {
      // Toggle between light and dark
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    }
    notifyListeners();
  }
}

// Global instance
final themeStore = ThemeStore();
