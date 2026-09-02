import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage_service.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _loadTheme();
  }

  void _loadTheme() {
    final mode = SecureStorageService().getThemeMode();
    if (mode == 'dark') {
      state = ThemeMode.dark;
    } else if (mode == 'system') {
      state = ThemeMode.system;
    } else {
      state = ThemeMode.light;
    }
  }

  void toggleTheme() {
    if (state == ThemeMode.light) {
      setTheme(ThemeMode.dark);
    } else {
      setTheme(ThemeMode.light);
    }
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    String modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    if (mode == ThemeMode.system) modeStr = 'system';
    SecureStorageService().saveThemeMode(modeStr);
  }
}
