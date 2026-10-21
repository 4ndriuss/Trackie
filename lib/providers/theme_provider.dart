import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [ThemeProvider] mengelola tema aplikasi (Light / Dark / System)
/// dengan persistensi lokal ke [SharedPreferences] (ARCH-12 & BUG-18).
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'trackie_theme_mode';

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider({ThemeMode initialMode = ThemeMode.light}) : _themeMode = initialMode {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themeKey);
      if (savedMode != null) {
        if (savedMode == 'dark') {
          _themeMode = ThemeMode.dark;
        } else if (savedMode == 'light') {
          _themeMode = ThemeMode.light;
        } else if (savedMode == 'system') {
          _themeMode = ThemeMode.system;
        }
        notifyListeners();
      }
    } catch (_) {
      // Ignored in test environment
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = mode == ThemeMode.dark
          ? 'dark'
          : mode == ThemeMode.light
              ? 'light'
              : 'system';
      await prefs.setString(_themeKey, modeStr);
    } catch (_) {
      // Ignored in test environment
    }
  }

  void toggleTheme() {
    setThemeMode(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
