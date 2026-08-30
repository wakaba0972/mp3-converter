import 'package:flutter/material.dart';

import 'controllers/theme_controller.dart';
import 'screens/batch_converter_screen.dart';

class Mp3ConverterApp extends StatefulWidget {
  const Mp3ConverterApp({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  State<Mp3ConverterApp> createState() => _Mp3ConverterAppState();
}

class _Mp3ConverterAppState extends State<Mp3ConverterApp> {
  @override
  void initState() {
    super.initState();
    widget.themeController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    widget.themeController.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '影片轉 MP3',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB69DF8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      themeMode: widget.themeController.isDarkMode
          ? ThemeMode.dark
          : ThemeMode.light,
      home: BatchConverterScreen(
        isDarkMode: widget.themeController.isDarkMode,
        onToggleTheme: widget.themeController.toggle,
      ),
    );
  }
}
