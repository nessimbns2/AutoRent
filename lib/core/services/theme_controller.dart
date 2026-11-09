import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the light / dark preference. Plain [ValueNotifier] — no external
/// state-management package (course constraint).
class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _key = 'theme_mode';

  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  bool get isDark => mode.value == ThemeMode.dark;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    mode.value = switch (saved) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }

  Future<void> setDark(bool dark) =>
      setMode(dark ? ThemeMode.dark : ThemeMode.light);

  Future<void> setMode(ThemeMode m) async {
    mode.value = m;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, m.name);
  }
}
