import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_converter/src/controllers/converter_controller.dart';
import 'package:mp3_converter/src/models/audio_quality.dart';
import 'package:mp3_converter/src/models/conversion_status.dart';
import 'package:mp3_converter/src/models/selected_video.dart';
import 'package:mp3_converter/src/services/conversion_services.dart';

import 'support/fake_services.dart';

void main() {
  late Directory tempDirectory;
  late File videoFile;
  late FakePicker picker;
  late FakeConverter converter;
  late FakeResultActions actions;
  late FakeOutputPaths outputPaths;
  late ConverterController controller;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('mp3_converter_test');
    videoFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}sample.mp4',
    );
    await videoFile.writeAsBytes([0, 1, 2]);
    picker = FakePicker(
      SelectedVideo(path: videoFile.path, name: 'sample.mp4', sizeBytes: 3),
    );
    converter = FakeConverter();
    actions = FakeResultActions();
    outputPaths = FakeOutputPaths();
    controller = ConverterController(
      picker: picker,
      outputPaths: outputPaths,
      converter: converter,
      resultActions: actions,
    );
  });

  tearDown(() async {
    controller.dispose();
    await tempDirectory.delete(recursive: true);
  });

  test('selecting a video prepares the default settings', () async {
    await controller.selectVideo();
    expect(controller.status, ConversionStatus.ready);
    expect(controller.outputName, 'sample');
    expect(controller.quality, AudioQuality.balanced);
    expect(controller.canConvert, isTrue);
  });

  test('successful conversion reports progress and exposes actions', () async {
    await controller.selectVideo();
    controller.setQuality(AudioQuality.high);
    await controller.convert();
    expect(controller.status, ConversionStatus.completed);
    expect(controller.progress, 1);
    expect(converter.receivedQuality, AudioQuality.high);
    expect(controller.outputPath, 'output/sample.mp3');
    expect(outputPaths.publishedPaths, ['output/sample.mp3']);
    await controller.openResult();
    await controller.shareResult();
    expect(actions.opened, controller.outputPath);
    expect(actions.shared, controller.outputPath);
  });

  test('video without audio fails with a useful message', () async {
    converter.details = const MediaDetails(
      duration: Duration(seconds: 10),
      hasAudio: false,
    );
    await controller.selectVideo();
    await controller.convert();
    expect(controller.status, ConversionStatus.failed);
    expect(controller.errorMessage, contains('沒有可轉換的音軌'));
  });

  test('cancelled conversion clears the output path', () async {
    converter.result = const ConversionResult(ConversionOutcome.cancelled);
    await controller.selectVideo();
    await controller.convert();
    expect(controller.status, ConversionStatus.cancelled);
    expect(controller.outputPath, isNull);
  });
}
