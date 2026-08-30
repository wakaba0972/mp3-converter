import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/controllers/theme_controller.dart';
import 'src/services/theme_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = ThemeController(SharedPreferencesThemeStore());
  await themeController.load();
  runApp(Mp3ConverterApp(themeController: themeController));
}
