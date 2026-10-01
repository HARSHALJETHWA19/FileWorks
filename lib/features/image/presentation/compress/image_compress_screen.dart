import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import '../../../../core/constants/route_constants.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../shared/models/processing_result.dart';
import '../../../../shared/presentation/processing_screen.dart';
import '../../../../shared/widgets/file_picker_helper.dart';
import '../../../history/models/history_item.dart';
import '../../../history/providers/history_provider.dart';
import '../../../monetization/ad_service.dart';
import '../../../monetization/free_usage_config.dart';
import '../../../monetization/presentation/banner_ad_widget.dart';
import '../../../monetization/providers/monetization_provider.dart';
import '../../../monetization/services/free_limit_helper.dart';
import '../../models/image_models.dart';
import '../../providers/image_providers.dart';

class ImageCompressScreen extends ConsumerStatefulWidget {
  const ImageCompressScreen({super.key});

  @override
  ConsumerState<ImageCompressScreen> createState() => _ImageCompressScreenState();
}

class _ImageCompressScreenState extends ConsumerState<ImageCompressScreen> {
  final List<File> _selectedImages = [];
  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusText = '';

  ImageCompressMode _mode = ImageCompressMode.quality;
  int _quality = 70; // 1 - 100
  int _targetBytes = 500 * 1024; // 500 KB default
  String _selectedPreset = '500kb'; // '100kb', '200kb', '500kb', '2mb', 'custom'
  final TextEditingController _customSizeController = TextEditingController(text: '300');
  String _customUnit = 'KB';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adServiceProvider).preloadInterstitialAd();
    });
  }

  @override
  void dispose() {
    _customSizeController.dispose();
    super.dispose();
  }

  void _updateCustomTarget() {
    final text = _customSizeController.text.trim();
    final value = double.tryParse(text);
    if (value != null && value > 0) {
      if (_customUnit == 'MB') {
        _targetBytes = (value * 1024 * 1024).round().clamp(10 * 1024, 100 * 1024 * 1024);
      } else {
        _targetBytes = (value * 1024).round().clamp(10 * 1024, 100 * 1024 * 1024);
      }
    }
  }

  Future<void> _pickImages() async {
    final images = await FilePickerHelper.pickImageFiles(allowMultiple: true);
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  Future<void> _processCompress() async {
    if (_selectedImages.isEmpty) return;

    int totalInputBytes = 0;
    for (final img in _selectedImages) {
      if (await img.exists()) {
        totalInputBytes += await img.length();
      }
    }
    if (!mounted) return;

    final allowed = await FreeLimitHelper.checkAndEnforce(
      context: context,
      ref: ref,
      feature: ToolFeature.imageCompress,
      requestedAmount: totalInputBytes,
    );
    if (!allowed) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _statusText = 'Compressing images...';
    });

    try {
      final imageService = ref.read(imageServiceProvider);
      int originalTotalBytes = 0;
      for (final img in _selectedImages) {
        if (await img.exists()) {
          originalTotalBytes += await img.length();
        }
      }

      final outputFiles = <File>[];

      for (int i = 0; i < _selectedImages.length; i++) {
        final img = _selectedImages[i];
        final baseName = p.basename(img.path);
        File compressed;

        if (_mode == ImageCompressMode.quality) {
          compressed = await imageService.compressImage(
            img,
            _quality,
            'compressed_$baseName',
          );
        } else {
          compressed = await imageService.compressToTargetSize(
            img,
            _targetBytes,
            'compressed_$baseName',
          );
        }

        outputFiles.add(compressed);
        if (mounted) {
          setState(() {
            _progress = (i + 1) / _selectedImages.length;
            _statusText = 'Compressed ${i + 1} of ${_selectedImages.length} images';
          });
        }
      }

      int outputTotalBytes = 0;
      for (final out in outputFiles) {
        if (await out.exists()) {
          outputTotalBytes += await out.length();
        }
      }

      final savings = FileUtils.calculateSavings(originalTotalBytes, outputTotalBytes);

      // Add to history
      final historyItem = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        toolName: 'Image Compress',
        title: outputFiles.length == 1
            ? p.basename(outputFiles.first.path)
            : '${outputFiles.length} Images Compressed',
        subtitle: '${savings.toStringAsFixed(1)}% size reduction',
        filePaths: outputFiles.map((f) => f.path).toList(),
        originalBytes: originalTotalBytes,
        outputBytes: outputTotalBytes,
        timestamp: DateTime.now(),
      );
      await ref.read(historyProvider.notifier).addHistoryItem(historyItem);
      ref.read(freeUsageManagerProvider).consumeReward(ToolFeature.imageCompress);
      ref.read(freeUsageManagerProvider).recordFeatureUsage(ToolFeature.imageCompress);

      await ref.read(adServiceProvider).maybeShowTransitionInterstitial(
        point: AdTransitionPoint.processingComplete,
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        // Evaluate target-size achievement if in targetSize mode
        String message;
        if (_mode == ImageCompressMode.targetSize) {
          final allUnderTarget = outputFiles.every((f) => f.existsSync() && f.lengthSync() <= _targetBytes);
          final formattedTarget = FileUtils.formatBytes(_targetBytes);
          if (allUnderTarget) {
            message = 'Target reached! All images reduced under $formattedTarget.';
          } else {
            message = 'Reduced file size by ${savings.toStringAsFixed(1)}%. Quality limit reached for requested target ($formattedTarget).';
          }
        } else {
          message = 'Reduced file size by ${savings.toStringAsFixed(1)}% locally.';
        }

        context.pushReplacement(
          RouteConstants.result,
          extra: ProcessingResult(
            success: true,
            feature: ToolFeature.imageCompress,
            title: 'Image Compression Complete',
            message: message,
            outputFiles: outputFiles,
            originalTotalBytes: originalTotalBytes,
            outputTotalBytes: outputTotalBytes,
            repeatRoute: RouteConstants.imageCompress,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error compressing image(s): $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return ProcessingScreen(
        title: 'Compressing Image...',
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
      title: 'Compress Image',
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
                              Icons.tune_rounded,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Select Images to Compress',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Reduce image file sizes while preserving visual clarity on your device.',
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
                        // Selected Overview Card
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

                        // Compression Mode Selector
                        Text(
                          'COMPRESSION MODE',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<ImageCompressMode>(
                          segments: const [
                            ButtonSegment(
                              value: ImageCompressMode.quality,
                              label: Text('Quality Slider'),
                            ),
                            ButtonSegment(
                              value: ImageCompressMode.targetSize,
                              label: Text('Target File Size'),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (set) => setState(() => _mode = set.first),
                        ),
                        const SizedBox(height: 20),

                        // Quality Slider or Target Size Choices
                        if (_mode == ImageCompressMode.quality) ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Quality Percentage',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$_quality%',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Slider(
                                    value: _quality.toDouble(),
                                    min: 10,
                                    max: 95,
                                    divisions: 17,
                                    label: '$_quality%',
                                    onChanged: (val) =>
                                        setState(() => _quality = val.round()),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Smallest Size',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        'Highest Quality',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          Card(
                            child: Column(
                              children: [
                                RadioListTile<String>(
                                  title: const Text('< 100 KB'),
                                  subtitle: const Text('Strict exam, government & job portal forms'),
                                  value: '100kb',
                                  groupValue: _selectedPreset,
                                  onChanged: (val) => setState(() {
                                    _selectedPreset = val!;
                                    _targetBytes = 100 * 1024;
                                  }),
                                ),
                                const Divider(height: 1),
                                RadioListTile<String>(
                                  title: const Text('< 200 KB'),
                                  subtitle: const Text('Standard resume & online portal uploads'),
                                  value: '200kb',
                                  groupValue: _selectedPreset,
                                  onChanged: (val) => setState(() {
                                    _selectedPreset = val!;
                                    _targetBytes = 200 * 1024;
                                  }),
                                ),
                                const Divider(height: 1),
                                RadioListTile<String>(
                                  title: const Text('< 500 KB'),
                                  subtitle: const Text('Great for email attachments & web uploads'),
                                  value: '500kb',
                                  groupValue: _selectedPreset,
                                  onChanged: (val) => setState(() {
                                    _selectedPreset = val!;
                                    _targetBytes = 500 * 1024;
                                  }),
                                ),
                                const Divider(height: 1),
                                RadioListTile<String>(
                                  title: const Text('< 2 MB'),
                                  subtitle: const Text('Balanced high-resolution image compression'),
                                  value: '2mb',
                                  groupValue: _selectedPreset,
                                  onChanged: (val) => setState(() {
                                    _selectedPreset = val!;
                                    _targetBytes = 2 * 1024 * 1024;
                                  }),
                                ),
                                const Divider(height: 1),
                                RadioListTile<String>(
                                  title: const Text('Custom Target Size'),
                                  subtitle: const Text('Specify exact maximum KB or MB'),
                                  value: 'custom',
                                  groupValue: _selectedPreset,
                                  onChanged: (val) => setState(() {
                                    _selectedPreset = val!;
                                    _updateCustomTarget();
                                  }),
                                ),
                                if (_selectedPreset == 'custom') ...[
                                  const Divider(height: 1),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _customSizeController,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Maximum Size',
                                              border: OutlineInputBorder(),
                                              isDense: true,
                                            ),
                                            onChanged: (_) => _updateCustomTarget(),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SegmentedButton<String>(
                                          segments: const [
                                            ButtonSegment(value: 'KB', label: Text('KB')),
                                            ButtonSegment(value: 'MB', label: Text('MB')),
                                          ],
                                          selected: {_customUnit},
                                          onSelectionChanged: (set) => setState(() {
                                            _customUnit = set.first;
                                            _updateCustomTarget();
                                          }),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          if (_selectedImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: PrimaryButton(
                label: 'Compress ${_selectedImages.length} Image${_selectedImages.length > 1 ? 's' : ''}',
                icon: Icons.tune_rounded,
                width: double.infinity,
                onPressed: _processCompress,
              ),
            ),
          if (_selectedImages.isEmpty)
            const BannerAdContainer(),
        ],
      ),
    );
  }
}
