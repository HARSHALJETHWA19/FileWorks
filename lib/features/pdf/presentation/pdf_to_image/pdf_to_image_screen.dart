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
import '../../../monetization/presentation/rewarded_unlock_card.dart';
import '../../../monetization/providers/monetization_provider.dart';
import '../../../monetization/services/free_limit_helper.dart';
import '../../providers/pdf_providers.dart';

class PdfToImageScreen extends ConsumerStatefulWidget {
  const PdfToImageScreen({super.key});

  @override
  ConsumerState<PdfToImageScreen> createState() => _PdfToImageScreenState();
}

class _PdfToImageScreenState extends ConsumerState<PdfToImageScreen> {
  File? _selectedFile;
  int _totalPages = 0;
  bool _isLoading = false;
  bool _isProcessing = false;
  double _progress = 0.0;
  String _progressText = '';

  bool _isPng = false; // false = JPG, true = PNG
  String _pageScope = 'all'; // 'all', 'custom'
  final TextEditingController _customPagesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adServiceProvider).preloadInterstitialAd();
    });
  }

  Future<void> _pickFile() async {
    final file = await FilePickerHelper.pickSinglePdfFile();
    if (file != null) {
      setState(() {
        _selectedFile = file;
        _isLoading = true;
      });

      try {
        final pdfService = ref.read(pdfServiceProvider);
        final count = await pdfService.getPageCount(file);
        setState(() {
          _totalPages = count;
          _isLoading = false;
        });
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to read PDF: $e')),
          );
        }
      }
    }
  }

  Future<void> _processConversion() async {
    if (_selectedFile == null || _totalPages == 0) return;

    List<int> pagesToConvert;
    if (_pageScope == 'all') {
      pagesToConvert = List.generate(_totalPages, (i) => i + 1);
    } else {
      pagesToConvert = FileUtils.parsePageRange(_customPagesController.text, _totalPages);
      if (pagesToConvert.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid page numbers.')),
        );
        return;
      }
    }

    final allowed = await FreeLimitHelper.checkAndEnforce(
      context: context,
      ref: ref,
      feature: ToolFeature.pdfToImage,
      requestedAmount: pagesToConvert.length,
    );
    if (!allowed) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _progressText = 'Starting page conversion...';
    });

    try {
      final pdfService = ref.read(pdfServiceProvider);
      final originalBytes = await _selectedFile!.length();

      final outputImages = await pdfService.pdfToImages(
        _selectedFile!,
        pages: pagesToConvert,
        isPng: _isPng,
        quality: 90,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _progress = current / total;
              _progressText = 'Converted page $current of $total';
            });
          }
        },
      );

      int totalOutputBytes = 0;
      for (final f in outputImages) {
        if (await f.exists()) {
          totalOutputBytes += await f.length();
        }
      }

      final baseName = p.basenameWithoutExtension(_selectedFile!.path);

      // Add to history
      final historyItem = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        toolName: 'PDF to Image',
        title: '$baseName (${_isPng ? 'PNG' : 'JPG'})',
        subtitle: '${outputImages.length} images exported',
        filePaths: outputImages.map((f) => f.path).toList(),
        originalBytes: originalBytes,
        outputBytes: totalOutputBytes,
        timestamp: DateTime.now(),
      );
      await ref.read(historyProvider.notifier).addHistoryItem(historyItem);
      ref.read(freeUsageManagerProvider).consumeReward(ToolFeature.pdfToImage);
      ref.read(freeUsageManagerProvider).recordFeatureUsage(ToolFeature.pdfToImage);

      await ref.read(adServiceProvider).maybeShowTransitionInterstitial(
        point: AdTransitionPoint.processingComplete,
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        context.pushReplacement(
          RouteConstants.result,
          extra: ProcessingResult(
            success: true,
            feature: ToolFeature.pdfToImage,
            title: 'Images Exported Successfully',
            message: 'Extracted ${outputImages.length} page images locally.',
            outputFiles: outputImages,
            originalTotalBytes: originalBytes,
            outputTotalBytes: totalOutputBytes,
            repeatRoute: RouteConstants.pdfToImage,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error extracting images: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _customPagesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return ProcessingScreen(
        title: 'Converting Pages to Images...',
        statusMessage: _progressText,
        progress: _progress,
      );
    }

    final theme = Theme.of(context);

    return AppScaffold(
      title: 'PDF to Image',
      body: Column(
        children: [
          Expanded(
            child: _selectedFile == null
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
                              Icons.photo_library_rounded,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Select PDF to Convert',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Convert pages into high-resolution JPG or PNG images on your device.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            label: 'Select PDF',
                            icon: Icons.add_circle_outline_rounded,
                            onPressed: _pickFile,
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
                                Icons.picture_as_pdf_rounded,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              p.basename(_selectedFile!.path),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: _isLoading
                                ? const Text('Loading pages...')
                                : Text('$_totalPages pages • ${FileUtils.formatBytes(_selectedFile!.lengthSync())}'),
                            trailing: TextButton(
                              onPressed: _pickFile,
                              child: const Text('Change'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'OUTPUT FORMAT',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('JPG (Smaller size)')),
                            ButtonSegment(value: true, label: Text('PNG (Lossless)')),
                          ],
                          selected: {_isPng},
                          onSelectionChanged: (set) => setState(() => _isPng = set.first),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'PAGES TO CONVERT',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          child: Column(
                            children: [
                              RadioListTile<String>(
                                title: const Text('All Pages'),
                                subtitle: Text('Extract all $_totalPages pages as images'),
                                value: 'all',
                                groupValue: _pageScope,
                                onChanged: (val) => setState(() => _pageScope = val!),
                              ),
                              const Divider(height: 1),
                              RadioListTile<String>(
                                title: const Text('Custom Page Range'),
                                subtitle: const Text('Select specific pages to extract'),
                                value: 'custom',
                                groupValue: _pageScope,
                                onChanged: (val) => setState(() => _pageScope = val!),
                              ),
                            ],
                          ),
                        ),
                        if (_pageScope == 'custom') ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: _customPagesController,
                            decoration: InputDecoration(
                              labelText: 'Pages to extract (e.g. 1-3, 5)',
                              hintText: '1-$_totalPages',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const RewardedUnlockCard(feature: ToolFeature.pdfToImage),
                      ],
                    ),
                  ),
          ),
          if (_selectedFile != null && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: PrimaryButton(
                label: 'Extract Images',
                icon: Icons.photo_library_rounded,
                width: double.infinity,
                onPressed: _processConversion,
              ),
            ),
          if (_selectedFile == null)
            const BannerAdContainer(),
        ],
      ),
    );
  }
}
