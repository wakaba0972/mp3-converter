import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_converter/src/controllers/batch_converter_controller.dart';
import 'package:mp3_converter/src/models/selected_video.dart';
import 'package:mp3_converter/src/screens/batch_converter_screen.dart';

import 'support/fake_services.dart';

void main() {
  late Directory tempDirectory;
  late BatchConverterController controller;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('batch_widget');
    final videos = <SelectedVideo>[];
    for (var index = 1; index <= 2; index++) {
      final file = File(
        '${tempDirectory.path}${Platform.pathSeparator}clip$index.mp4',
      );
      await file.writeAsBytes([index]);
      videos.add(
        SelectedVideo(
          path: file.path,
          name: 'clip$index.mp4',
          sizeBytes: 1024 * index,
        ),
      );
    }
    controller = BatchConverterController(
      picker: FakeBatchPicker(videos),
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
      MaterialApp(home: BatchConverterScreen(controller: controller)),
    );
  }

  testWidgets('shows an empty batch state', (tester) async {
    await pumpScreen(tester);

    expect(find.text('尚未加入影片'), findsOneWidget);
    expect(find.text('選擇多個影片'), findsOneWidget);
    expect(find.text('輸出位置：Download/MP3 Converter'), findsOneWidget);
    expect(find.byKey(const Key('toggle-theme')), findsOneWidget);
    expect(find.byKey(const Key('start-batch')), findsNothing);
  });

  testWidgets('shows all selected videos and batch action', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('add-videos')));
    await tester.pump();

    expect(find.text('clip1.mp4'), findsOneWidget);
    expect(find.text('clip2.mp4'), findsOneWidget);
    expect(find.text('開始轉換 2 個檔案'), findsOneWidget);
  });

  testWidgets('completed batch displays per-file result actions', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('add-videos')));
    await tester.pump();
    await tester.runAsync(controller.startBatch);
    await tester.pumpAndSettle();

    expect(find.text('轉換完成'), findsNWidgets(2));
    expect(find.byTooltip('播放'), findsNWidgets(2));
    expect(find.byTooltip('分享'), findsNWidgets(2));
  });
}
