import 'dart:io';

const _invalidAndroidFileNameCharacters = r'<>:"/\|?*';

String defaultOutputName(String sourceName) {
  final trimmed = sourceName.trim();
  return trimmed.toLowerCase().endsWith('.mp4')
      ? trimmed.substring(0, trimmed.length - 4)
      : trimmed;
}

String normalizeOutputName(String value) {
  var result = value.trim();
  while (result.toLowerCase().endsWith('.mp3')) {
    result = result.substring(0, result.length - 4).trimRight();
  }
  return result;
}

String? validateOutputName(String value) {
  final normalized = normalizeOutputName(value);
  if (normalized.isEmpty) {
    return '請輸入輸出檔名';
  }
  if (normalized == '.' || normalized == '..') {
    return '請輸入有效的輸出檔名';
  }
  if (normalized.codeUnits.any((character) => character < 32) ||
      normalized.split('').any(_invalidAndroidFileNameCharacters.contains)) {
    return '檔名不可包含 < > : " / \\ | ? *';
  }
  if (normalized.endsWith('.') || normalized.endsWith(' ')) {
    return '檔名不可使用空白或句點結尾';
  }
  return null;
}

Future<String> availableOutputPath(
  String directory,
  String outputName, {
  bool Function(String path)? exists,
}) async {
  final normalized = normalizeOutputName(outputName);
  final separator = Platform.pathSeparator;
  final fileExists = exists ?? (path) => File(path).existsSync();
  var candidate = '$directory$separator$normalized.mp3';
  var suffix = 1;
  while (fileExists(candidate)) {
    candidate = '$directory$separator$normalized ($suffix).mp3';
    suffix++;
  }
  return candidate;
}
