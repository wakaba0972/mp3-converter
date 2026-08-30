import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_converter/src/controllers/batch_converter_controller.dart';
import 'package:mp3_converter/src/models/audio_quality.dart';
import 'package:mp3_converter/src/models/conversion_status.dart';
import 'package:mp3_converter/src/models/selected_video.dart';
import 'package:mp3_converter/src/services/conversion_services.dart';

import 'support/fake_services.dart';

void main() {
  late Directory tempDirectory;
  late List<SelectedVideo> videos;
  late FakeBatchPicker picker;
  late FakeConverter converter;
  late FakeOutputPaths outputPaths;
  late BatchConverterController controller;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('batch_test');
    videos = [];
    for (var index = 1; index <= 3; index++) {
      final file = File(
        '${tempDirectory.path}${Platform.pathSeparator}video$index.mp4',
      );
      await file.writeAsBytes([index]);
      videos.add(
        SelectedVideo(path: file.path, name: 'video$index.mp4', sizeBytes: 1),
      );
    }
    picker = FakeBatchPicker(videos);
    converter = FakeConverter();
    outputPaths = FakeOutputPaths();
    controller = BatchConverterController(
      picker: picker,
      outputPaths: outputPaths,
      converter: converter,
      resultActions: FakeResultActions(),
    );
  });

  tearDown(() async {
    controller.dispose();
    await tempDirectory.delete(recursive: true);
  });

  test('adds multiple videos and ignores duplicate paths', () async {
    await controller.addVideos();
    await controller.addVideos();

    expect(controller.items, hasLength(3));
    expect(controller.items.map((item) => item.outputName), [
      'video1',
      'video2',
      'video3',
    ]);
  });

  test('converts the queue sequentially with the selected quality', () async {
    await controller.addVideos();
    controller.setQuality(AudioQuality.high);
    await controller.startBatch();

    expect(converter.convertedInputs, videos.map((video) => video.path));
    expect(converter.receivedQuality, AudioQuality.high);
    expect(
      controller.items.map((item) => item.status),
      everyElement(ConversionStatus.completed),
    );
    expect(controller.overallProgress, 1);
    expect(controller.successCount, 3);
    expect(outputPaths.publishedPaths, hasLength(3));
  });

  test('continues with later files after one conversion fails', () async {
    converter.queuedResults.addAll([
      const ConversionResult(ConversionOutcome.success),
      const ConversionResult(ConversionOutcome.failed, message: '測試失敗'),
      const ConversionResult(ConversionOutcome.success),
    ]);
    await controller.addVideos();
    await controller.startBatch();

    expect(controller.items[0].status, ConversionStatus.completed);
    expect(controller.items[1].status, ConversionStatus.failed);
    expect(controller.items[1].errorMessage, '測試失敗');
    expect(controller.items[2].status, ConversionStatus.completed);
    expect(converter.convertedInputs, hasLength(3));
  });

  test('invalid output name prevents starting the batch', () async {
    await controller.addVideos();
    controller.updateOutputName(controller.items.first, 'bad:name');

    expect(controller.canStart, isFalse);
  });

  test('removes an item before conversion', () async {
    await controller.addVideos();
    final removed = controller.items[1];
    controller.removeItem(removed);

    expect(controller.items, hasLength(2));
    expect(controller.items, isNot(contains(removed)));
  });

  test(
    'cancelling stops the active conversion and cancels queued items',
    () async {
      final blockingConverter = _BlockingConverter();
      controller.dispose();
      controller = BatchConverterController(
        picker: picker,
        outputPaths: FakeOutputPaths(),
        converter: blockingConverter,
        resultActions: FakeResultActions(),
      );
      await controller.addVideos();

      final batchFuture = controller.startBatch();
      await blockingConverter.started.future;
      final cancelFuture = controller.cancelBatch();
      blockingConverter.finishCancelled();
      await cancelFuture;
      await batchFuture;

      expect(blockingConverter.cancelled, isTrue);
      expect(
        controller.items.map((item) => item.status),
        everyElement(ConversionStatus.cancelled),
      );
    },
  );
}

class _BlockingConverter implements AudioConversionService {
  final started = Completer<void>();
  final _result = Completer<ConversionResult>();
  bool cancelled = false;

  @override
  Future<void> cancel() async {
    cancelled = true;
  }

  void finishCancelled() {
    _result.complete(const ConversionResult(ConversionOutcome.cancelled));
  }

  @override
  Future<ConversionResult> convert({
    required String inputPath,
    required String outputPath,
    required AudioQuality quality,
    required Duration duration,
    required void Function(Duration processed) onProgress,
  }) {
    started.complete();
    return _result.future;
  }

  @override
  Future<MediaDetails> inspect(String inputPath) async =>
      const MediaDetails(duration: Duration(minutes: 1), hasAudio: true);
}
