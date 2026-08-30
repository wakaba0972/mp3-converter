import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_converter/src/controllers/converter_controller.dart';
import 'package:mp3_converter/src/models/conversion_status.dart';
import 'package:mp3_converter/src/models/selected_video.dart';
import 'package:mp3_converter/src/screens/converter_screen.dart';

import 'support/fake_services.dart';

void main() {
  late Directory tempDirectory;
  late ConverterController controller;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('widget_test');
    final file = File('${tempDirectory.path}${Platform.pathSeparator}demo.mp4');
    await file.writeAsBytes([0]);
    controller = ConverterController(
      picker: FakePicker(
        SelectedVideo(path: file.path, name: 'demo.mp4', sizeBytes: 1024),
      ),
      outputPaths: FakeOutputPaths(),
      converter: FakeConverter(),
      resultActions: FakeResultActions(),
    );
  });

  tearDown(() async {
    controller.dispose();
    await tempDirectory.delete(recursive: true);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ConverterScreen(controller: controller)),
    );
  }

  testWidgets('initial screen cannot start conversion', (tester) async {
    await pumpScreen(tester);
    expect(find.text('選擇影片檔案'), findsOneWidget);
    expect(find.byKey(const Key('start-conversion')), findsNothing);
  });

  testWidgets('selected video shows metadata and default output name', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('pick-video')));
    await tester.pump();
    expect(find.text('demo.mp4'), findsOneWidget);
    expect(find.text('1.0 KB'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'demo'), findsOneWidget);
    expect(find.byKey(const Key('start-conversion')), findsOneWidget);
  });

  testWidgets('invalid name disables conversion and shows validation', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('pick-video')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('output-name')), 'bad:name');
    await tester.pump();
    expect(find.textContaining('檔名不可包含'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('start-conversion')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('successful conversion shows result actions', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('pick-video')));
    await tester.pump();
    await tester.runAsync(controller.convert);
    await tester.pumpAndSettle();
    expect(controller.status, ConversionStatus.completed);
    expect(find.text('轉換完成'), findsOneWidget);
    expect(find.text('播放'), findsOneWidget);
    expect(find.text('分享'), findsOneWidget);
    expect(find.byKey(const Key('convert-another')), findsOneWidget);
  });
}
