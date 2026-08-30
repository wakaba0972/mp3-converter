import 'package:flutter/material.dart';

import '../controllers/batch_converter_controller.dart';
import '../models/audio_quality.dart';
import '../models/batch_item.dart';
import '../models/conversion_status.dart';
import '../services/native_services.dart';
import '../utils/file_name_utils.dart';
import '../utils/formatters.dart';

class BatchConverterScreen extends StatefulWidget {
  const BatchConverterScreen({super.key, this.controller});

  final BatchConverterController? controller;

  @override
  State<BatchConverterScreen> createState() => _BatchConverterScreenState();
}

class _BatchConverterScreenState extends State<BatchConverterScreen> {
  late final BatchConverterController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        BatchConverterController(
          picker: NativeVideoPickerService(),
          outputPaths: NativeOutputPathService(),
          converter: FfmpegAudioConversionService(),
          resultActions: NativeResultActionService(),
        );
    _controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('批量 MP4 轉 MP3'),
        actions: [
          if (_controller.items.any((item) => item.isFinished) &&
              !_controller.isRunning)
            IconButton(
              key: const Key('clear-finished'),
              onPressed: _controller.clearFinished,
              tooltip: '清除已完成項目',
              icon: const Icon(Icons.cleaning_services_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _BatchHeader(controller: _controller),
            if (_controller.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _controller.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: _controller.items.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      itemCount: _controller.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _BatchItemCard(
                        key: ValueKey(_controller.items[index].video.path),
                        index: index,
                        item: _controller.items[index],
                        controller: _controller,
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomActions(controller: _controller),
    );
  }
}

class _BatchHeader extends StatelessWidget {
  const _BatchHeader({required this.controller});

  final BatchConverterController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            key: const Key('add-videos'),
            onPressed: controller.isRunning ? null : controller.addVideos,
            icon: const Icon(Icons.video_library_outlined),
            label: const Text('選擇多個 MP4'),
          ),
          if (controller.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('音質'),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<AudioQuality>(
                    key: const Key('batch-quality'),
                    segments: [
                      for (final quality in AudioQuality.values)
                        ButtonSegment(
                          value: quality,
                          label: Text('${quality.kbps}'),
                          tooltip: quality.description,
                        ),
                    ],
                    selected: {controller.quality},
                    onSelectionChanged: controller.isRunning
                        ? null
                        : (values) => controller.setQuality(values.single),
                  ),
                ),
              ],
            ),
          ],
          if (controller.isRunning) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: controller.overallProgress),
            const SizedBox(height: 6),
            Text(
              '批次進度 ${controller.completedCount}/${controller.items.length} '
              '(${(controller.overallProgress * 100).round()}%)',
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music, size: 72),
            SizedBox(height: 12),
            Text('尚未加入影片'),
            SizedBox(height: 4),
            Text('一次選擇多個 MP4，App 會依序轉換以節省手機資源。'),
          ],
        ),
      ),
    );
  }
}

class _BatchItemCard extends StatelessWidget {
  const _BatchItemCard({
    super.key,
    required this.index,
    required this.item,
    required this.controller,
  });

  final int index;
  final BatchItem item;
  final BatchConverterController controller;

  @override
  Widget build(BuildContext context) {
    final nameError = validateOutputName(item.outputName);
    final progress = normalizedProgress(
      item.processed.inMilliseconds,
      item.duration.inMilliseconds,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text('${index + 1}')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.video.name, overflow: TextOverflow.ellipsis),
                      Text(formatBytes(item.video.sizeBytes)),
                    ],
                  ),
                ),
                if (!controller.isRunning)
                  IconButton(
                    key: Key('remove-$index'),
                    onPressed: () => controller.removeItem(item),
                    tooltip: '移除 ${item.video.name}',
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: Key('output-name-$index'),
              initialValue: item.outputName,
              enabled: !controller.isRunning,
              onChanged: (value) => controller.updateOutputName(item, value),
              decoration: InputDecoration(
                labelText: '輸出檔名',
                suffixText: '.mp3',
                errorText: nameError,
                isDense: true,
              ),
            ),
            if (item.status == ConversionStatus.converting) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 4),
              Text(
                '轉換中 ${formatDuration(item.processed)} / '
                '${formatDuration(item.duration)}',
              ),
            ] else if (item.status != ConversionStatus.ready) ...[
              const SizedBox(height: 10),
              _ItemResult(item: item, controller: controller),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemResult extends StatelessWidget {
  const _ItemResult({required this.item, required this.controller});

  final BatchItem item;
  final BatchConverterController controller;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (item.status) {
      ConversionStatus.completed => (Icons.check_circle, '轉換完成'),
      ConversionStatus.failed => (
        Icons.error_outline,
        item.errorMessage ?? '轉換失敗',
      ),
      ConversionStatus.cancelled => (Icons.cancel_outlined, '已取消'),
      _ => (Icons.hourglass_empty, '等待中'),
    };
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
        if (item.status == ConversionStatus.completed) ...[
          IconButton(
            onPressed: () => controller.openResult(item),
            tooltip: '播放',
            icon: const Icon(Icons.play_arrow),
          ),
          IconButton(
            onPressed: () => controller.shareResult(item),
            tooltip: '分享',
            icon: const Icon(Icons.share),
          ),
        ],
      ],
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.controller});

  final BatchConverterController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.items.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: controller.isRunning
            ? OutlinedButton.icon(
                key: const Key('cancel-batch'),
                onPressed: controller.cancelBatch,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('取消批次'),
              )
            : FilledButton.icon(
                key: const Key('start-batch'),
                onPressed: controller.canStart ? controller.startBatch : null,
                icon: const Icon(Icons.playlist_play),
                label: Text('開始轉換 ${controller.items.length} 個檔案'),
              ),
      ),
    );
  }
}
