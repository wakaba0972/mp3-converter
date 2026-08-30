import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_converter/src/utils/file_name_utils.dart';

void main() {
  group('defaultOutputName', () {
    test('removes supported video extensions case-insensitively', () {
      expect(defaultOutputName('My Video.MP4'), 'My Video');
      expect(defaultOutputName('My Video.MkV'), 'My Video');
      expect(defaultOutputName('My Video.webm'), 'My Video');
    });

    test('keeps names with unsupported extensions', () {
      expect(defaultOutputName('recording.txt'), 'recording.txt');
    });
  });

  test('recognizes supported video paths', () {
    expect(isSupportedVideoPath('/videos/movie.MOV'), isTrue);
    expect(isSupportedVideoPath('/videos/movie.m2ts'), isTrue);
    expect(isSupportedVideoPath('/videos/audio.mp3'), isFalse);
    expect(isSupportedVideoPath('/videos/no-extension'), isFalse);
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
