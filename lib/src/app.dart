import 'package:flutter/material.dart';

import 'screens/batch_converter_screen.dart';

class Mp3ConverterApp extends StatelessWidget {
  const Mp3ConverterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MP4 轉 MP3',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const BatchConverterScreen(),
    );
  }
}
