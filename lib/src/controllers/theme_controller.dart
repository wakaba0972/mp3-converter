import 'package:flutter/foundation.dart';

import '../services/theme_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._store);

  final ThemePreferenceStore _store;

  bool isDarkMode = false;

  Future<void> load() async {
    try {
      isDarkMode = await _store.readDarkMode() ?? false;
    } catch (_) {
      isDarkMode = false;
    }
  }

  Future<void> setDarkMode(bool enabled) async {
    if (isDarkMode == enabled) return;
    isDarkMode = enabled;
    notifyListeners();
    try {
      await _store.writeDarkMode(enabled);
    } catch (_) {
      isDarkMode = !enabled;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggle() => setDarkMode(!isDarkMode);
}
