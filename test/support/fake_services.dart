import 'package:mp3_converter/src/models/audio_quality.dart';
import 'package:mp3_converter/src/models/selected_video.dart';
import 'package:mp3_converter/src/services/conversion_services.dart';

class FakePicker implements VideoPickerService {
  FakePicker([this.selection]);
  SelectedVideo? selection;

  @override
  Future<SelectedVideo?> pickMp4() async => selection;
}

class FakeBatchPicker implements BatchVideoPickerService {
  FakeBatchPicker([this.selections = const []]);
  List<SelectedVideo> selections;

  @override
  Future<List<SelectedVideo>> pickMp4s() async => selections;
}

class FakeOutputPaths implements OutputPathService {
  final List<String> publishedPaths = [];

  @override
  Future<String> createOutputPath(String outputName) async =>
      'output/$outputName.mp3';

  @override
  Future<String> publishOutput(String temporaryPath, String outputName) async {
    publishedPaths.add(temporaryPath);
    return temporaryPath;
  }
}

class FakeConverter implements AudioConversionService {
  MediaDetails details = const MediaDetails(
    duration: Duration(minutes: 1),
    hasAudio: true,
  );
  ConversionResult result = const ConversionResult(ConversionOutcome.success);
  bool cancelled = false;
  AudioQuality? receivedQuality;
  final List<String> convertedInputs = [];
  final List<ConversionResult> queuedResults = [];

  @override
  Future<void> cancel() async {
    cancelled = true;
  }

  @override
  Future<ConversionResult> convert({
    required String inputPath,
    required String outputPath,
    required AudioQuality quality,
    required Duration duration,
    required void Function(Duration processed) onProgress,
  }) async {
    receivedQuality = quality;
    convertedInputs.add(inputPath);
    onProgress(const Duration(seconds: 30));
    return queuedResults.isEmpty ? result : queuedResults.removeAt(0);
  }

  @override
  Future<MediaDetails> inspect(String inputPath) async => details;
}

class FakeResultActions implements ResultActionService {
  String? opened;
  String? shared;

  @override
  Future<void> open(String path) async => opened = path;

  @override
  Future<void> share(String path) async => shared = path;
}
