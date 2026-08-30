import '../models/audio_quality.dart';
import '../models/selected_video.dart';

class MediaDetails {
  const MediaDetails({required this.duration, required this.hasAudio});

  final Duration duration;
  final bool hasAudio;
}

enum ConversionOutcome { success, failed, cancelled }

class ConversionResult {
  const ConversionResult(this.outcome, {this.message});

  final ConversionOutcome outcome;
  final String? message;
}

abstract interface class VideoPickerService {
  Future<SelectedVideo?> pickMp4();
}

abstract interface class BatchVideoPickerService {
  Future<List<SelectedVideo>> pickMp4s();
}

abstract interface class OutputPathService {
  Future<String> createOutputPath(String outputName);
}

abstract interface class AudioConversionService {
  Future<MediaDetails> inspect(String inputPath);

  Future<ConversionResult> convert({
    required String inputPath,
    required String outputPath,
    required AudioQuality quality,
    required Duration duration,
    required void Function(Duration processed) onProgress,
  });

  Future<void> cancel();
}

abstract interface class ResultActionService {
  Future<void> open(String path);
  Future<void> share(String path);
}
