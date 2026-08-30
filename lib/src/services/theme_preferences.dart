import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ThemePreferenceStore {
  Future<bool?> readDarkMode();
  Future<void> writeDarkMode(bool enabled);
}

class SharedPreferencesThemeStore implements ThemePreferenceStore {
  static const _darkModeKey = 'dark_mode_enabled';

  @override
  Future<bool?> readDarkMode() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_darkModeKey);
  }

  @override
  Future<void> writeDarkMode(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setBool(_darkModeKey, enabled);
    if (!saved) throw StateError('無法儲存暗黑模式設定');
  }
}
