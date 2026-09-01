import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/audio_quality.dart';
import '../models/selected_video.dart';
import '../utils/file_name_utils.dart';
import 'conversion_services.dart';

class NativeVideoPickerService
    implements VideoPickerService, BatchVideoPickerService {
  static const _channel = MethodChannel('mp3_converter/video_picker');

  @override
  Future<SelectedVideo?> pickMp4() async {
    if (Platform.isAndroid) {
      final videos = await _pickAndroidVideos(allowMultiple: false);
      return videos.firstOrNull;
    }
    final selected = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: supportedVideoExtensions.toList(),
    );
    if (selected == null) return null;
    final path = selected.path;
    if (path == null || !isSupportedVideoPath(path)) {
      throw const FileSystemException('請選擇支援的影片檔案');
    }
    final file = File(path);
    if (!await file.exists()) {
      throw const FileSystemException('找不到選擇的檔案，請重新選擇');
    }
    return SelectedVideo(
      path: path,
      name: selected.name,
      sizeBytes: await selected.length(),
    );
  }

  @override
  Future<List<SelectedVideo>> pickMp4s() async {
    if (Platform.isAndroid) {
      return _pickAndroidVideos(allowMultiple: true);
    }
    final selectedFiles = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedVideoExtensions.toList(),
    );
    final videos = <SelectedVideo>[];
    for (final selected in selectedFiles) {
      final path = selected.path;
      if (path == null || !isSupportedVideoPath(path)) continue;
      final file = File(path);
      if (!await file.exists()) continue;
      videos.add(
        SelectedVideo(
          path: path,
          name: selected.name,
          sizeBytes: await selected.length(),
        ),
      );
    }
    if (selectedFiles.isNotEmpty && videos.isEmpty) {
      throw const FileSystemException('選擇的檔案無法讀取，請重新選擇');
    }
    return videos;
  }

  Future<List<SelectedVideo>> _pickAndroidVideos({
    required bool allowMultiple,
  }) async {
    final raw = await _channel.invokeListMethod<Object?>('pickVideos', {
      'allowMultiple': allowMultiple,
    });
    if (raw == null) return const [];
    final videos = <SelectedVideo>[];
    for (final value in raw) {
      if (value is! Map) continue;
      final uri = value['uri'] as String?;
      final name = value['name'] as String?;
      final size = value['size'] as int? ?? 0;
      if (uri == null || name == null || !isSupportedVideoPath(name)) continue;
      videos.add(SelectedVideo(path: uri, name: name, sizeBytes: size));
    }
    if (raw.isNotEmpty && videos.isEmpty) {
      throw const FileSystemException('選擇的檔案格式不受支援，請重新選擇');
    }
    return videos;
  }
}

class NativeOutputPathService implements OutputPathService {
  static const publicFolder = 'MP3 Converter';
  final MediaStore _mediaStore = MediaStore();
  bool _initialized = false;

  @override
  Future<String> createOutputPath(String outputName) async {
    await _ensureInitialized();
    final availableName = await _availablePublicName(outputName);
    final root = await getTemporaryDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}conversions',
    );
    await directory.create(recursive: true);
    return '${directory.path}${Platform.pathSeparator}$availableName.mp3';
  }

  @override
  Future<String> publishOutput(String temporaryPath, String outputName) async {
    await _ensureInitialized();
    final saved = await _mediaStore.saveFile(
      tempFilePath: temporaryPath,
      dirType: DirType.download,
      dirName: DirName.download,
    );
    if (saved == null) {
      throw const FileSystemException('無法將 MP3 儲存到公共 Download 資料夾');
    }
    final temporary = File(temporaryPath);
    if (await temporary.exists()) await temporary.delete();
    return saved.uri.toString();
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = publicFolder;
    _initialized = true;
    await _migrateLegacyOutputs();
  }

  Future<void> _migrateLegacyOutputs() async {
    try {
      final legacyRoot = await getDownloadsDirectory();
      if (legacyRoot == null) return;
      final legacyDirectory = Directory(
        '${legacyRoot.path}${Platform.pathSeparator}$publicFolder',
      );
      if (!await legacyDirectory.exists()) return;
      await for (final entry in legacyDirectory.list()) {
        if (entry is! File || !entry.path.toLowerCase().endsWith('.mp3')) {
          continue;
        }
        await _mediaStore.saveFile(
          tempFilePath: entry.path,
          dirType: DirType.download,
          dirName: DirName.download,
        );
      }
    } catch (error) {
      debugPrint('Unable to migrate legacy MP3 outputs: $error');
    }
  }

  Future<String> _availablePublicName(String outputName) async {
    final normalized = normalizeOutputName(outputName);
    var candidate = normalized;
    var suffix = 1;
    while (await _mediaStore.isFileExist(
      fileName: '$candidate.mp3',
      dirType: DirType.download,
      dirName: DirName.download,
    )) {
      candidate = '$normalized ($suffix)';
      suffix++;
    }
    return candidate;
  }
}

class FfmpegAudioConversionService implements AudioConversionService {
  int? _activeSessionId;

  @override
  Future<MediaDetails> inspect(String inputPath) async {
    final resolvedInput = await _resolveInput(inputPath);
    final session = await FFprobeKit.getMediaInformation(resolvedInput);
    final information = session.getMediaInformation();
    if (information == null) {
      throw const FormatException('無法讀取影片資訊，檔案可能已損壞');
    }
    final hasAudio = information.getStreams().any(
      (stream) => stream.getType() == 'audio',
    );
    final durationSeconds =
        double.tryParse(information.getDuration() ?? '') ?? 0;
    return MediaDetails(
      duration: Duration(milliseconds: (durationSeconds * 1000).round()),
      hasAudio: hasAudio,
    );
  }

  @override
  Future<ConversionResult> convert({
    required String inputPath,
    required String outputPath,
    required AudioQuality quality,
    required Duration duration,
    required void Function(Duration processed) onProgress,
  }) async {
    final resolvedInput = await _resolveInput(inputPath);
    final completer = Completer<ConversionResult>();
    final session = await FFmpegKit.executeWithArgumentsAsync(
      [
        '-y',
        '-i',
        resolvedInput,
        '-vn',
        '-map',
        '0:a:0',
        '-c:a',
        'libmp3lame',
        '-b:a',
        quality.ffmpegBitrate,
        outputPath,
      ],
      (completedSession) async {
        final returnCode = await completedSession.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          completer.complete(const ConversionResult(ConversionOutcome.success));
        } else if (ReturnCode.isCancel(returnCode)) {
          await _deletePartialOutput(outputPath);
          completer.complete(
            const ConversionResult(ConversionOutcome.cancelled),
          );
        } else {
          final logs = await completedSession.getAllLogsAsString();
          await _deletePartialOutput(outputPath);
          debugPrint('FFmpeg conversion failed: $logs');
          completer.complete(
            const ConversionResult(
              ConversionOutcome.failed,
              message: '轉換失敗，請確認影片內容完整後再試一次',
            ),
          );
        }
        _activeSessionId = null;
      },
      null,
      (statistics) {
        onProgress(Duration(milliseconds: statistics.getTime()));
      },
    );
    _activeSessionId = session.getSessionId();
    return completer.future;
  }

  @override
  Future<void> cancel() async {
    final sessionId = _activeSessionId;
    if (sessionId != null) await FFmpegKit.cancel(sessionId);
  }

  Future<String> _resolveInput(String inputPath) async {
    if (!inputPath.startsWith('content://')) return inputPath;
    final safInput = await FFmpegKitConfig.getSafParameterForRead(inputPath);
    if (safInput == null || safInput.isEmpty) {
      throw const FileSystemException('無法開啟選擇的影片，請重新選擇');
    }
    return safInput;
  }

  Future<void> _deletePartialOutput(String outputPath) async {
    final output = File(outputPath);
    if (await output.exists()) await output.delete();
  }
}

class NativeResultActionService implements ResultActionService {
  @override
  Future<void> open(String path) async {
    final result = await OpenFilex.open(path, type: 'audio/mpeg');
    if (result.type != ResultType.done) {
      throw StateError('無法開啟 MP3，請確認手機已安裝音樂播放器');
    }
  }

  @override
  Future<void> share(String path) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: '由 MP4 轉 MP3 產生的音訊'),
    );
  }
}
