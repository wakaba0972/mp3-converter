enum AudioQuality {
  compact(128, '較小檔案'),
  balanced(192, '平衡音質與容量'),
  high(320, '較高音質');

  const AudioQuality(this.kbps, this.description);

  final int kbps;
  final String description;

  String get label => '$kbps kbps';
  String get ffmpegBitrate => '${kbps}k';
}
