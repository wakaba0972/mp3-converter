import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_converter/src/utils/file_name_utils.dart';

void main() {
  group('defaultOutputName', () {
    test('removes the MP4 extension case-insensitively', () {
      expect(defaultOutputName('My Video.MP4'), 'My Video');
    });

    test('keeps names without an MP4 extension', () {
      expect(defaultOutputName('recording.mov'), 'recording.mov');
    });
  });

  group('normalizeOutputName', () {
    test('trims whitespace and repeated MP3 extensions', () {
      expect(normalizeOutputName('  song.mp3.MP3  '), 'song');
    });
  });

  group('validateOutputName', () {
    test('accepts a normal name', () {
      expect(validateOutputName('我的音訊'), isNull);
    });

    test('rejects empty and invalid Android names', () {
      expect(validateOutputName(' .mp3 '), isNotNull);
      expect(validateOutputName('bad:name'), isNotNull);
      expect(validateOutputName('name.'), isNotNull);
    });
  });

  test('availableOutputPath adds an increasing suffix', () async {
    final path = await availableOutputPath(
      'output',
      'audio',
      exists: (candidate) =>
          candidate.endsWith('audio.mp3') ||
          candidate.endsWith('audio (1).mp3'),
    );

    expect(path, endsWith('audio (2).mp3'));
  });
}
