import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_converter/src/models/audio_quality.dart';
import 'package:mp3_converter/src/models/selected_video.dart';
import 'package:mp3_converter/src/models/conversion_status.dart';
import 'package:mp3_converter/src/utils/formatters.dart';

void main() {
  test('selected videos identify streaming Android content URIs', () {
    const streamed = SelectedVideo(
      path: 'content://media/external/video/42',
      name: 'large.mp4',
      sizeBytes: 600 * 1024 * 1024,
    );
    const local = SelectedVideo(
      path: '/storage/emulated/0/Movies/large.mp4',
      name: 'large.mp4',
      sizeBytes: 600 * 1024 * 1024,
    );

    expect(streamed.isContentUri, isTrue);
    expect(local.isContentUri, isFalse);
  });

  test('audio qualities expose the expected FFmpeg bitrates', () {
    expect(AudioQuality.values.map((quality) => quality.ffmpegBitrate), [
      '128k',
      '192k',
      '320k',
    ]);
  });

  test('conversion status includes every MVP state', () {
    expect(ConversionStatus.values, [
      ConversionStatus.empty,
      ConversionStatus.ready,
      ConversionStatus.converting,
      ConversionStatus.completed,
      ConversionStatus.failed,
      ConversionStatus.cancelled,
    ]);
  });

  test('progress is clamped to the zero-to-one range', () {
    expect(normalizedProgress(-1, 100), 0);
    expect(normalizedProgress(50, 100), 0.5);
    expect(normalizedProgress(120, 100), 1);
    expect(normalizedProgress(10, 0), 0);
  });

  test('formats sizes and durations for display', () {
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
    expect(formatDuration(const Duration(seconds: 65)), '01:05');
    expect(formatDuration(const Duration(hours: 1, seconds: 2)), '1:00:02');
  });
}
