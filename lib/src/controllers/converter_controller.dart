import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/audio_quality.dart';
import '../models/conversion_status.dart';
import '../models/selected_video.dart';
import '../services/conversion_services.dart';
import '../utils/file_name_utils.dart';
import '../utils/formatters.dart';

class ConverterController extends ChangeNotifier {
  ConverterController({
    required VideoPickerService picker,
    required OutputPathService outputPaths,
    required AudioConversionService converter,
    required ResultActionService resultActions,
  }) : _picker = picker, // ignore: prefer_initializing_formals
       _outputPaths = outputPaths, // ignore: prefer_initializing_formals
       _converter = converter, // ignore: prefer_initializing_formals
       _resultActions = resultActions; // ignore: prefer_initializing_formals

  final VideoPickerService _picker;
  final OutputPathService _outputPaths;
  final AudioConversionService _converter;
  final ResultActionService _resultActions;

  SelectedVideo? video;
  String outputName = '';
  AudioQuality quality = AudioQuality.balanced;
  ConversionStatus status = ConversionStatus.empty;
  Duration duration = Duration.zero;
  Duration processed = Duration.zero;
  String? outputPath;
  String? errorMessage;

  String? get outputNameError => validateOutputName(outputName);
  double get progress =>
      normalizedProgress(processed.inMilliseconds, duration.inMilliseconds);
  bool get isConverting => status == ConversionStatus.converting;
  bool get canConvert =>
      video != null && outputNameError == null && !isConverting;

  Future<void> selectVideo() async {
    if (isConverting) return;
    try {
      final selection = await _picker.pickMp4();
      if (selection == null) return;
      video = selection;
      outputName = defaultOutputName(selection.name);
      status = ConversionStatus.ready;
      duration = Duration.zero;
      processed = Duration.zero;
      outputPath = null;
      errorMessage = null;
      notifyListeners();
    } on FileSystemException catch (error) {
      _fail(error.message);
    } catch (_) {
      _fail('無法讀取選擇的檔案，請重新選擇');
    }
  }

  void setOutputName(String value) {
    if (isConverting) return;
    outputName = value;
    notifyListeners();
  }

  void setQuality(AudioQuality value) {
    if (isConverting) return;
    quality = value;
    notifyListeners();
  }

  Future<void> convert() async {
    final selected = video;
    if (!canConvert || selected == null) return;
    status = ConversionStatus.converting;
    outputName = normalizeOutputName(outputName);
    processed = Duration.zero;
    errorMessage = null;
    notifyListeners();

    try {
      if (!await File(selected.path).exists()) {
        throw const FileSystemException('來源檔案已被移動或刪除，請重新選擇');
      }
      final details = await _converter.inspect(selected.path);
      if (!details.hasAudio) {
        throw const FormatException('這個 MP4 沒有可轉換的音軌');
      }
      duration = details.duration;
      outputPath = await _outputPaths.createOutputPath(outputName);
      notifyListeners();

      final result = await _converter.convert(
        inputPath: selected.path,
        outputPath: outputPath!,
        quality: quality,
        duration: duration,
        onProgress: (value) {
          processed = value;
          notifyListeners();
        },
      );
      switch (result.outcome) {
        case ConversionOutcome.success:
          processed = duration;
          status = ConversionStatus.completed;
        case ConversionOutcome.cancelled:
          status = ConversionStatus.cancelled;
          outputPath = null;
        case ConversionOutcome.failed:
          status = ConversionStatus.failed;
          errorMessage = result.message ?? '轉換失敗，請稍後再試';
          outputPath = null;
      }
      notifyListeners();
    } on FileSystemException catch (error) {
      _fail(error.message);
    } on FormatException catch (error) {
      _fail(error.message);
    } catch (_) {
      _fail('轉換失敗，請確認儲存空間與檔案內容後再試');
    }
  }

  Future<void> cancel() async {
    if (!isConverting) return;
    await _converter.cancel();
  }

  Future<void> openResult() async => _runResultAction(_resultActions.open);

  Future<void> shareResult() async => _runResultAction(_resultActions.share);

  void reset() {
    if (isConverting) return;
    video = null;
    outputName = '';
    quality = AudioQuality.balanced;
    status = ConversionStatus.empty;
    duration = Duration.zero;
    processed = Duration.zero;
    outputPath = null;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> _runResultAction(Future<void> Function(String) action) async {
    final path = outputPath;
    if (path == null) return;
    try {
      await action(path);
    } catch (error) {
      errorMessage = error is StateError ? error.message : '無法完成操作，請稍後再試';
      notifyListeners();
    }
  }

  void _fail(String message) {
    status = ConversionStatus.failed;
    errorMessage = message;
    notifyListeners();
  }
}
