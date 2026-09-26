import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../core/constants/route_constants.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../shared/models/processing_result.dart';
import '../../../../shared/presentation/processing_screen.dart';
import '../../../../shared/presentation/result_screen.dart';
import '../../../../shared/widgets/file_picker_helper.dart';
import '../../../history/models/history_item.dart';
import '../../../history/providers/history_provider.dart';
import '../../../monetization/free_usage_config.dart';
import '../../../monetization/providers/monetization_provider.dart';
import '../../../monetization/services/free_limit_helper.dart';
import '../../models/image_models.dart';
import '../../providers/image_providers.dart';

class ImageConvertScreen extends ConsumerStatefulWidget {
  const ImageConvertScreen({super.key});

  @override
  ConsumerState<ImageConvertScreen> createState() => _ImageConvertScreenState();
}

class _ImageConvertScreenState extends ConsumerState<ImageConvertScreen> {
  final List<File> _selectedImages = [];
  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusText = '';

  ImageFormatType _targetFormat = ImageFormatType.jpg;

  Future<void> _pickImages() async {
    final images = await FilePickerHelper.pickImageFiles(allowMultiple: true);
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  Future<void> _processConvert() async {
    if (_selectedImages.isEmpty) return;

    int maxFileSizeBytes = 0;
    for (final img in _selectedImages) {
      if (await img.exists()) {
        final len = await img.length();
        if (len > maxFileSizeBytes) maxFileSizeBytes = len;
      }
    }
    if (!mounted) return;

    final allowed = await FreeLimitHelper.checkAndEnforce(
      context: context,
      ref: ref,
      feature: ToolFeature.imageConvert,
      requestedAmount: maxFileSizeBytes,
    );
    if (!allowed) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _statusText = 'Converting images...';
    });

    try {
      final imageService = ref.read(imageServiceProvider);
      int originalTotalBytes = 0;
      for (final img in _selectedImages) {
        if (await img.exists()) originalTotalBytes += await img.length();
      }

      final outputFiles = await imageService.batchConvert(
        images: _selectedImages,
        targetFormat: _targetFormat,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _progress = current / total;
              _statusText = 'Converted $current of $total images';
            });
          }
        },
      );

      int outputTotalBytes = 0;
      for (final out in outputFiles) {
        if (await out.exists()) outputTotalBytes += await out.length();
      }

      // Add to history
      final historyItem = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        toolName: 'Image Convert',
        title: outputFiles.length == 1
            ? p.basename(outputFiles.first.path)
            : '${outputFiles.length} Images to ${_targetFormat.label}',
        subtitle: 'Converted to ${_targetFormat.label}',
        filePaths: outputFiles.map((f) => f.path).toList(),
        originalBytes: originalTotalBytes,
        outputBytes: outputTotalBytes,
        timestamp: DateTime.now(),
      );
      await ref.read(historyProvider.notifier).addHistoryItem(historyItem);
      ref.read(freeUsageManagerProvider).consumeReward(ToolFeature.imageConvert);
      ref.read(freeUsageManagerProvider).recordFeatureUsage(ToolFeature.imageConvert);

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              result: ProcessingResult(
                success: true,
                title: 'Conversion Complete',
                message: 'Successfully converted ${outputFiles.length} files to ${_targetFormat.label}.',
                outputFiles: outputFiles,
                originalTotalBytes: originalTotalBytes,
                outputTotalBytes: outputTotalBytes,
                repeatRoute: RouteConstants.imageConvert,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error converting images: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return ProcessingScreen(
        title: 'Converting Images...',
        statusMessage: _statusText,
        progress: _progress,
      );
    }

    final theme = Theme.of(context);

    int totalSelectedBytes = 0;
    for (final img in _selectedImages) {
      if (img.existsSync()) totalSelectedBytes += img.lengthSync();
    }

    return AppScaffold(
      title: 'Convert Image',
      body: Column(
        children: [
          Expanded(
            child: _selectedImages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer.withAlpha(80),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.transform_rounded,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Select Images to Convert',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Convert image formats between JPG, PNG, and WEBP on your device.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            label: 'Select Images',
                            icon: Icons.add_photo_alternate_rounded,
                            onPressed: _pickImages,
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer.withAlpha(120),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.image_rounded,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              '${_selectedImages.length} Image${_selectedImages.length > 1 ? 's' : ''} Selected',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text('Total size: ${FileUtils.formatBytes(totalSelectedBytes)}'),
                            trailing: TextButton.icon(
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add More'),
                              onPressed: _pickImages,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'TARGET FORMAT',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<ImageFormatType>(
                          segments: const [
                            ButtonSegment(
                              value: ImageFormatType.jpg,
                              label: Text('JPG / JPEG'),
                            ),
                            ButtonSegment(
                              value: ImageFormatType.png,
                              label: Text('PNG (Lossless)'),
                            ),
                            ButtonSegment(
                              value: ImageFormatType.webp,
                              label: Text('WEBP (Modern)'),
                            ),
                          ],
                          selected: {_targetFormat},
                          onSelectionChanged: (set) =>
                              setState(() => _targetFormat = set.first),
                        ),
                        const SizedBox(height: 20),

                        if (_targetFormat == ImageFormatType.jpg)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 18, color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'JPG format does not support transparency. Any transparent background in PNG/WEBP files will be seamlessly filled with solid white.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          if (_selectedImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: PrimaryButton(
                label: 'Convert to ${_targetFormat.label}',
                icon: Icons.transform_rounded,
                width: double.infinity,
                onPressed: _processConvert,
              ),
            ),
        ],
      ),
    );
  }
}
