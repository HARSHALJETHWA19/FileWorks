import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../core/constants/route_constants.dart';
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

class ImageResizeScreen extends ConsumerStatefulWidget {
  const ImageResizeScreen({super.key});

  @override
  ConsumerState<ImageResizeScreen> createState() => _ImageResizeScreenState();
}

class _ImageResizeScreenState extends ConsumerState<ImageResizeScreen> {
  final List<File> _selectedImages = [];
  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusText = '';

  ImageResizePreset _preset = ImageResizePreset.fullHd;
  final TextEditingController _widthController = TextEditingController(text: '1920');
  final TextEditingController _heightController = TextEditingController(text: '1080');
  bool _maintainAspect = true;
  bool _avoidUpscaling = true;

  int? _originalWidth;
  int? _originalHeight;

  Future<void> _pickImages() async {
    final images = await FilePickerHelper.pickImageFiles(allowMultiple: true);
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.clear();
        _selectedImages.addAll(images);
      });

      if (images.length == 1) {
        try {
          final imageService = ref.read(imageServiceProvider);
          final dims = await imageService.getImageDimensions(images.first);
          setState(() {
            _originalWidth = dims['width'];
            _originalHeight = dims['height'];
          });
        } catch (_) {}
      }
    }
  }

  void _onPresetChanged(ImageResizePreset preset) {
    setState(() {
      _preset = preset;
      if (preset != ImageResizePreset.custom) {
        _widthController.text = preset.width.toString();
        _heightController.text = preset.height.toString();
      }
    });
  }

  Future<void> _processResize() async {
    if (_selectedImages.isEmpty) return;

    final targetW = int.tryParse(_widthController.text.trim()) ?? 0;
    final targetH = int.tryParse(_heightController.text.trim()) ?? 0;

    if (targetW <= 0 && targetH <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid width or height.')),
      );
      return;
    }

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
      feature: ToolFeature.imageResize,
      requestedAmount: maxFileSizeBytes,
    );
    if (!allowed) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _statusText = 'Resizing images...';
    });

    try {
      final imageService = ref.read(imageServiceProvider);
      int originalTotalBytes = 0;
      for (final img in _selectedImages) {
        if (await img.exists()) originalTotalBytes += await img.length();
      }

      final outputFiles = <File>[];

      for (int i = 0; i < _selectedImages.length; i++) {
        final img = _selectedImages[i];
        final baseName = p.basename(img.path);

        final resized = await imageService.resizeImage(
          imageFile: img,
          targetWidth: targetW,
          targetHeight: targetH,
          maintainAspectRatio: _maintainAspect,
          outputName: 'resized_$baseName',
        );

        outputFiles.add(resized);
        if (mounted) {
          setState(() {
            _progress = (i + 1) / _selectedImages.length;
            _statusText = 'Resized ${i + 1} of ${_selectedImages.length} images';
          });
        }
      }

      int outputTotalBytes = 0;
      for (final out in outputFiles) {
        if (await out.exists()) outputTotalBytes += await out.length();
      }

      // Add to history
      final historyItem = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        toolName: 'Image Resize',
        title: outputFiles.length == 1
            ? p.basename(outputFiles.first.path)
            : '${outputFiles.length} Images Resized',
        subtitle: '${targetW}x$targetH target resolution',
        filePaths: outputFiles.map((f) => f.path).toList(),
        originalBytes: originalTotalBytes,
        outputBytes: outputTotalBytes,
        timestamp: DateTime.now(),
      );
      await ref.read(historyProvider.notifier).addHistoryItem(historyItem);
      ref.read(freeUsageManagerProvider).consumeReward(ToolFeature.imageResize);
      ref.read(freeUsageManagerProvider).recordFeatureUsage(ToolFeature.imageResize);

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              result: ProcessingResult(
                success: true,
                title: 'Image Resized Successfully',
                message: 'Adjusted resolution for ${outputFiles.length} images locally.',
                outputFiles: outputFiles,
                originalTotalBytes: originalTotalBytes,
                outputTotalBytes: outputTotalBytes,
                repeatRoute: RouteConstants.imageResize,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resizing image(s): $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return ProcessingScreen(
        title: 'Resizing Images...',
        statusMessage: _statusText,
        progress: _progress,
      );
    }

    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Resize Image',
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
                              Icons.aspect_ratio_rounded,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Select Images to Resize',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Scale image pixel dimensions using standard social & document presets.',
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
                              _selectedImages.length == 1
                                  ? p.basename(_selectedImages.first.path)
                                  : '${_selectedImages.length} Images Selected',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(_originalWidth != null && _originalHeight != null
                                ? 'Original: ${_originalWidth}x$_originalHeight px'
                                : '${_selectedImages.length} files to resize'),
                            trailing: TextButton(
                              onPressed: _pickImages,
                              child: const Text('Change'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Presets
                        Text(
                          'DIMENSION PRESETS',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ImageResizePreset.values.map((p) {
                            final isSelected = _preset == p;
                            return ChoiceChip(
                              label: Text(p.label),
                              selected: isSelected,
                              onSelected: (_) => _onPresetChanged(p),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // Width & Height inputs
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _widthController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Width (px)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onChanged: (_) => setState(() {
                                  _preset = ImageResizePreset.custom;
                                }),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text('×', style: TextStyle(fontSize: 22)),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _heightController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Height (px)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onChanged: (_) => setState(() {
                                  _preset = ImageResizePreset.custom;
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Card(
                          child: Column(
                            children: [
                              CheckboxListTile(
                                title: const Text('Maintain Aspect Ratio'),
                                subtitle: const Text('Prevent image distortion and stretching'),
                                value: _maintainAspect,
                                onChanged: (val) => setState(() => _maintainAspect = val ?? true),
                              ),
                              const Divider(height: 1),
                              CheckboxListTile(
                                title: const Text('Avoid Upscaling'),
                                subtitle: const Text('Do not enlarge images beyond original resolution'),
                                value: _avoidUpscaling,
                                onChanged: (val) =>
                                    setState(() => _avoidUpscaling = val ?? true),
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
                label: 'Resize ${_selectedImages.length} Image${_selectedImages.length > 1 ? 's' : ''}',
                icon: Icons.aspect_ratio_rounded,
                width: double.infinity,
                onPressed: _processResize,
              ),
            ),
        ],
      ),
    );
  }
}
