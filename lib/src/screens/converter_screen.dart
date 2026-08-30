import 'package:flutter/material.dart';

import '../controllers/converter_controller.dart';
import '../models/audio_quality.dart';
import '../models/conversion_status.dart';
import '../services/native_services.dart';
import '../utils/formatters.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key, this.controller});

  final ConverterController? controller;

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  late final ConverterController _controller;
  late final TextEditingController _nameController;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        ConverterController(
          picker: NativeVideoPickerService(),
          outputPaths: NativeOutputPathService(),
          converter: FfmpegAudioConversionService(),
          resultActions: NativeResultActionService(),
        );
    _nameController = TextEditingController(text: _controller.outputName);
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (_nameController.text != _controller.outputName) {
      _nameController.value = TextEditingValue(
        text: _controller.outputName,
        selection: TextSelection.collapsed(
          offset: _controller.outputName.length,
        ),
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) _controller.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MP4 轉 MP3')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.audio_file, size: 64),
                  const SizedBox(height: 8),
                  Text(
                    '在手機上安全地擷取影片音訊',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    key: const Key('pick-video'),
                    onPressed: _controller.isConverting
                        ? null
                        : _controller.selectVideo,
                    icon: const Icon(Icons.video_file_outlined),
                    label: Text(
                      _controller.video == null ? '選擇 MP4 檔案' : '更換 MP4',
                    ),
                  ),
                  if (_controller.video != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.movie_outlined),
                        title: Text(_controller.video!.name),
                        subtitle: Text(
                          formatBytes(_controller.video!.sizeBytes),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('output-name'),
                      controller: _nameController,
                      enabled: !_controller.isConverting,
                      onChanged: _controller.setOutputName,
                      decoration: InputDecoration(
                        labelText: '輸出檔名',
                        suffixText: '.mp3',
                        errorText: _controller.outputNameError,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('音質', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SegmentedButton<AudioQuality>(
                      key: const Key('quality-selector'),
                      segments: [
                        for (final quality in AudioQuality.values)
                          ButtonSegment(
                            value: quality,
                            label: Text('${quality.kbps}'),
                            tooltip: '${quality.label}：${quality.description}',
                          ),
                      ],
                      selected: {_controller.quality},
                      onSelectionChanged: _controller.isConverting
                          ? null
                          : (selection) =>
                                _controller.setQuality(selection.single),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const Key('start-conversion'),
                      onPressed: _controller.canConvert
                          ? _controller.convert
                          : null,
                      icon: const Icon(Icons.audiotrack),
                      label: const Text('開始轉換'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _StatusPanel(controller: _controller),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case ConversionStatus.empty:
      case ConversionStatus.ready:
        return const SizedBox.shrink();
      case ConversionStatus.converting:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: '轉換進度 ${(controller.progress * 100).round()}%',
              child: LinearProgressIndicator(value: controller.progress),
            ),
            const SizedBox(height: 10),
            Text(
              '正在轉換… ${formatDuration(controller.processed)} / '
              '${formatDuration(controller.duration)} '
              '(${(controller.progress * 100).round()}%)',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('cancel-conversion'),
              onPressed: controller.cancel,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('取消'),
            ),
          ],
        );
      case ConversionStatus.completed:
        return _ResultCard(
          icon: Icons.check_circle,
          title: '轉換完成',
          message: controller.outputPath ?? '',
          children: [
            OutlinedButton.icon(
              onPressed: controller.openResult,
              icon: const Icon(Icons.play_arrow),
              label: const Text('播放'),
            ),
            OutlinedButton.icon(
              onPressed: controller.shareResult,
              icon: const Icon(Icons.share),
              label: const Text('分享'),
            ),
            FilledButton(
              key: const Key('convert-another'),
              onPressed: controller.reset,
              child: const Text('再轉換一個'),
            ),
          ],
        );
      case ConversionStatus.failed:
        return _ResultCard(
          icon: Icons.error_outline,
          title: '無法完成轉換',
          message: controller.errorMessage ?? '請稍後再試',
          children: [
            if (controller.video != null)
              FilledButton(
                key: const Key('retry-conversion'),
                onPressed: controller.canConvert ? controller.convert : null,
                child: const Text('重試'),
              ),
          ],
        );
      case ConversionStatus.cancelled:
        return _ResultCard(
          icon: Icons.info_outline,
          title: '已取消轉換',
          message: '未完成的輸出檔案已清除，你可以調整設定後重試。',
          children: [
            FilledButton(
              key: const Key('retry-conversion'),
              onPressed: controller.canConvert ? controller.convert : null,
              child: const Text('重新轉換'),
            ),
          ],
        );
    }
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center),
            if (children.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: children),
            ],
          ],
        ),
      ),
    );
  }
}
