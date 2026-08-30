import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_converter/src/app.dart';
import 'package:mp3_converter/src/controllers/theme_controller.dart';
import 'package:mp3_converter/src/services/theme_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'shared preferences keeps dark mode across controller instances',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = ThemeController(SharedPreferencesThemeStore());
      await first.setDarkMode(true);

      final restarted = ThemeController(SharedPreferencesThemeStore());
      await restarted.load();

      expect(restarted.isDarkMode, isTrue);
    },
  );

  test('loads the saved dark mode setting on startup', () async {
    final store = _MemoryThemeStore(value: true);
    final controller = ThemeController(store);

    await controller.load();

    expect(controller.isDarkMode, isTrue);
  });

  test('persists a changed theme setting', () async {
    final store = _MemoryThemeStore();
    final controller = ThemeController(store);

    await controller.setDarkMode(true);

    expect(controller.isDarkMode, isTrue);
    expect(store.value, isTrue);
  });

  test('restores the previous mode when persistence fails', () async {
    final store = _MemoryThemeStore(shouldFail: true);
    final controller = ThemeController(store);

    await expectLater(controller.setDarkMode(true), throwsStateError);
    expect(controller.isDarkMode, isFalse);
  });

  testWidgets('theme button switches MaterialApp to dark mode', (tester) async {
    final store = _MemoryThemeStore();
    final controller = ThemeController(store);
    await tester.pumpWidget(Mp3ConverterApp(themeController: controller));

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    await tester.tap(find.byKey(const Key('toggle-theme')));
    await tester.pumpAndSettle();

    expect(controller.isDarkMode, isTrue);
    expect(store.value, isTrue);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(find.byTooltip('切換為淺色模式'), findsOneWidget);
  });
}

class _MemoryThemeStore implements ThemePreferenceStore {
  _MemoryThemeStore({this.value, this.shouldFail = false});

  bool? value;
  final bool shouldFail;

  @override
  Future<bool?> readDarkMode() async => value;

  @override
  Future<void> writeDarkMode(bool enabled) async {
    if (shouldFail) throw StateError('test failure');
    value = enabled;
  }
}
