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
import '../../models/pdf_models.dart';
import '../../providers/pdf_providers.dart';

class ImageToPdfScreen extends ConsumerStatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  ConsumerState<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends ConsumerState<ImageToPdfScreen> {
  final List<File> _selectedImages = [];
  final TextEditingController _nameController =
      TextEditingController(text: 'converted_images.pdf');
  bool _isProcessing = false;

  ImageToPdfPageSize _pageSize = ImageToPdfPageSize.a4;
  ImageToPdfOrientation _orientation = ImageToPdfOrientation.portrait;
  final ImageToPdfMargin _margin = ImageToPdfMargin.none;

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

    final allowed = await FreeLimitHelper.checkAndEnforce(
      context: context,
      ref: ref,
      feature: ToolFeature.imageToPdf,
      requestedAmount: _selectedImages.length,
    );
    if (!allowed) return;

    setState(() => _isProcessing = true);

    try {
      final pdfService = ref.read(pdfServiceProvider);
      final outputName = _nameController.text.trim().isEmpty
          ? 'converted_images.pdf'
          : _nameController.text.trim();

      int originalTotalBytes = 0;
      for (final img in _selectedImages) {
        if (await img.exists()) {
          originalTotalBytes += await img.length();
        }
      }

      final options = ImageToPdfOptions(
        pageSize: _pageSize,
        orientation: _orientation,
        margin: _margin,
      );

      final pdfFile = await pdfService.imagesToPdf(_selectedImages, options, outputName);
      final outputBytes = await pdfFile.length();

      // Record in history
      final historyItem = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        toolName: 'Image to PDF',
        title: p.basename(pdfFile.path),
        subtitle: '${_selectedImages.length} images converted',
        filePaths: [pdfFile.path],
        originalBytes: originalTotalBytes,
        outputBytes: outputBytes,
        timestamp: DateTime.now(),
      );
      await ref.read(historyProvider.notifier).addHistoryItem(historyItem);
      ref.read(freeUsageManagerProvider).consumeReward(ToolFeature.imageToPdf);
      ref.read(freeUsageManagerProvider).recordFeatureUsage(ToolFeature.imageToPdf);

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              result: ProcessingResult(
                success: true,
                title: 'PDF Created Successfully',
                message: 'Converted ${_selectedImages.length} images into a PDF document.',
                outputFiles: [pdfFile],
                originalTotalBytes: originalTotalBytes,
                outputTotalBytes: outputBytes,
                repeatRoute: RouteConstants.imageToPdf,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return const ProcessingScreen(
        title: 'Creating PDF...',
        statusMessage: 'Fitting and generating pages locally on your device.',
      );
    }

    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Image to PDF',
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
                              Icons.picture_as_pdf_rounded,
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
                            'Combine JPG, PNG, and WEBP photos into a clean PDF document.',
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
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_selectedImages.length} Images (Drag to reorder)',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextButton.icon(
                              onPressed: _pickImages,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add More'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ReorderableListView.builder(
                          itemCount: _selectedImages.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = _selectedImages.removeAt(oldIndex);
                              _selectedImages.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final image = _selectedImages[index];
                            final name = p.basename(image.path);
                            final sizeStr = image.existsSync()
                                ? FileUtils.formatBytes(image.lengthSync())
                                : '';

                            return Card(
                              key: ValueKey(image.path + index.toString()),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    image,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                                  ),
                                ),
                                title: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text('Page ${index + 1} • $sizeStr'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 18),
                                      onPressed: () {
                                        setState(() => _selectedImages.removeAt(index));
                                      },
                                    ),
                                    const Icon(Icons.drag_handle_rounded, color: Colors.grey),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Document Configuration Options
                      ExpansionTile(
                        initiallyExpanded: false,
                        title: const Text(
                          'Page Setup & Margin',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Text('Size:'),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: SegmentedButton<ImageToPdfPageSize>(
                                        segments: const [
                                          ButtonSegment(value: ImageToPdfPageSize.a4, label: Text('A4')),
                                          ButtonSegment(value: ImageToPdfPageSize.letter, label: Text('Letter')),
                                          ButtonSegment(value: ImageToPdfPageSize.original, label: Text('Original')),
                                        ],
                                        selected: {_pageSize},
                                        onSelectionChanged: (set) => setState(() => _pageSize = set.first),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Text('Orientation:'),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: SegmentedButton<ImageToPdfOrientation>(
                                        segments: const [
                                          ButtonSegment(value: ImageToPdfOrientation.portrait, label: Text('Portrait')),
                                          ButtonSegment(value: ImageToPdfOrientation.landscape, label: Text('Landscape')),
                                        ],
                                        selected: {_orientation},
                                        onSelectionChanged: (set) => setState(() => _orientation = set.first),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'PDF Filename',
                            suffixText: '.pdf',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          if (_selectedImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: PrimaryButton(
                label: 'Create PDF (${_selectedImages.length} Images)',
                icon: Icons.picture_as_pdf_rounded,
                width: double.infinity,
                onPressed: _processConvert,
              ),
            ),
        ],
      ),
    );
  }
}
