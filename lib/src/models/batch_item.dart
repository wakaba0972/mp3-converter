import 'conversion_status.dart';
import 'selected_video.dart';

class BatchItem {
  BatchItem({required this.video, required this.outputName});

  final SelectedVideo video;
  String outputName;
  ConversionStatus status = ConversionStatus.ready;
  Duration duration = Duration.zero;
  Duration processed = Duration.zero;
  String? outputPath;
  String? errorMessage;

  bool get isFinished =>
      status == ConversionStatus.completed ||
      status == ConversionStatus.failed ||
      status == ConversionStatus.cancelled;
}
