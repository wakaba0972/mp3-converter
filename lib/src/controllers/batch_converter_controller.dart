import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/audio_quality.dart';
import '../models/batch_item.dart';
import '../models/conversion_status.dart';
import '../services/conversion_services.dart';
import '../utils/file_name_utils.dart';
import '../utils/formatters.dart';

class BatchConverterController extends ChangeNotifier {
  BatchConverterController({
    required BatchVideoPickerService picker,
    required OutputPathService outputPaths,
    required AudioConversionService converter,
    required ResultActionService resultActions,
  }) : _picker = picker, // ignore: prefer_initializing_formals
       _outputPaths = outputPaths, // ignore: prefer_initializing_formals
       _converter = converter, // ignore: prefer_initializing_formals
       _resultActions = resultActions; // ignore: prefer_initializing_formals

  final BatchVideoPickerService _picker;
  final OutputPathService _outputPaths;
  final AudioConversionService _converter;
  final ResultActionService _resultActions;

  final List<BatchItem> items = [];
  AudioQuality quality = AudioQuality.balanced;
  bool isRunning = false;
  bool _cancelRequested = false;
  String? errorMessage;

  int get completedCount => items.where((item) => item.isFinished).length;
  int get successCount =>
      items.where((item) => item.status == ConversionStatus.completed).length;
  double get overallProgress {
    if (items.isEmpty) return 0;
    final total = items.fold<double>(0, (sum, item) {
      if (item.status == ConversionStatus.completed ||
          item.status == ConversionStatus.failed ||
          item.status == ConversionStatus.cancelled) {
        return sum + 1;
      }
      return sum +
          normalizedProgress(
            item.processed.inMilliseconds,
            item.duration.inMilliseconds,
          );
    });
    return (total / items.length).clamp(0.0, 1.0);
  }

  bool get canStart =>
      items.isNotEmpty &&
      !isRunning &&
      items.every((item) => validateOutputName(item.outputName) == null);

  Future<void> addVideos() async {
    if (isRunning) return;
    try {
      final selections = await _picker.pickMp4s();
      if (selections.isEmpty) return;
      final existingPaths = items.map((item) => item.video.path).toSet();
      for (final video in selections) {
        if (existingPaths.add(video.path)) {
          items.add(
            BatchItem(video: video, outputName: defaultOutputName(video.name)),
          );
        }
      }
      errorMessage = null;
      notifyListeners();
    } on FileSystemException catch (error) {
      errorMessage = error.message;
      notifyListeners();
    } catch (_) {
      errorMessage = '無法讀取選擇的檔案，請重新選擇';
      notifyListeners();
    }
  }

  void updateOutputName(BatchItem item, String value) {
    if (isRunning || !items.contains(item)) return;
    item.outputName = value;
    notifyListeners();
  }

  void removeItem(BatchItem item) {
    if (isRunning) return;
    items.remove(item);
    notifyListeners();
  }

  void clearFinished() {
    if (isRunning) return;
    items.removeWhere((item) => item.isFinished);
    notifyListeners();
  }

  void setQuality(AudioQuality value) {
    if (isRunning) return;
    quality = value;
    notifyListeners();
  }

  Future<void> startBatch() async {
    if (!canStart) return;
    isRunning = true;
    _cancelRequested = false;
    errorMessage = null;
    for (final item in items) {
      if (item.isFinished) {
        item
          ..status = ConversionStatus.ready
          ..processed = Duration.zero
          ..duration = Duration.zero
          ..outputPath = null
          ..errorMessage = null;
      }
    }
    notifyListeners();

    for (final item in items) {
      if (_cancelRequested) {
        if (!item.isFinished) item.status = ConversionStatus.cancelled;
        continue;
      }
      await _convertItem(item);
    }
    isRunning = false;
    _cancelRequested = false;
    notifyListeners();
  }

  Future<void> _convertItem(BatchItem item) async {
    item
      ..status = ConversionStatus.converting
      ..outputName = normalizeOutputName(item.outputName)
      ..processed = Duration.zero
      ..errorMessage = null
      ..outputPath = null;
    notifyListeners();

    try {
      if (!item.video.isContentUri && !await File(item.video.path).exists()) {
        throw const FileSystemException('來源檔案已被移動或刪除');
      }
      final details = await _converter.inspect(item.video.path);
      if (!details.hasAudio) {
        throw const FormatException('這個 MP4 沒有可轉換的音軌');
      }
      item.duration = details.duration;
      item.outputPath = await _outputPaths.createOutputPath(item.outputName);
      notifyListeners();
      final result = await _converter.convert(
        inputPath: item.video.path,
        outputPath: item.outputPath!,
        quality: quality,
        duration: item.duration,
        onProgress: (processed) {
          item.processed = processed;
          notifyListeners();
        },
      );
      switch (result.outcome) {
        case ConversionOutcome.success:
          item.outputPath = await _outputPaths.publishOutput(
            item.outputPath!,
            item.outputName,
          );
          item
            ..processed = item.duration
            ..status = ConversionStatus.completed;
        case ConversionOutcome.failed:
          item
            ..status = ConversionStatus.failed
            ..errorMessage = result.message ?? '轉換失敗，請稍後再試'
            ..outputPath = null;
        case ConversionOutcome.cancelled:
          item
            ..status = ConversionStatus.cancelled
            ..outputPath = null;
      }
    } on FileSystemException catch (error) {
      item
        ..status = ConversionStatus.failed
        ..errorMessage = error.message
        ..outputPath = null;
    } on FormatException catch (error) {
      item
        ..status = ConversionStatus.failed
        ..errorMessage = error.message
        ..outputPath = null;
    } catch (_) {
      item
        ..status = ConversionStatus.failed
        ..errorMessage = '轉換失敗，請確認儲存空間與檔案內容'
        ..outputPath = null;
    }
    notifyListeners();
  }

  Future<void> cancelBatch() async {
    if (!isRunning) return;
    _cancelRequested = true;
    await _converter.cancel();
    for (final item in items) {
      if (item.status == ConversionStatus.ready) {
        item.status = ConversionStatus.cancelled;
      }
    }
    notifyListeners();
  }

  Future<void> openResult(BatchItem item) async {
    final path = item.outputPath;
    if (path == null) return;
    await _runAction(item, () => _resultActions.open(path));
  }

  Future<void> shareResult(BatchItem item) async {
    final path = item.outputPath;
    if (path == null) return;
    await _runAction(item, () => _resultActions.share(path));
  }

  Future<void> _runAction(
    BatchItem item,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      item.errorMessage = error is StateError ? error.message : '無法完成操作，請稍後再試';
      notifyListeners();
    }
  }
}
