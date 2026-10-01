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
import '../../models/pdf_models.dart';
import '../../providers/pdf_providers.dart';

class PdfSplitScreen extends ConsumerStatefulWidget {
  const PdfSplitScreen({super.key});

  @override
  ConsumerState<PdfSplitScreen> createState() => _PdfSplitScreenState();
}

class _PdfSplitScreenState extends ConsumerState<PdfSplitScreen> {
  File? _selectedFile;
  int _totalPages = 0;
  bool _isLoadingPages = false;
  bool _isProcessing = false;

  PdfSplitMode _mode = PdfSplitMode.everyPage;
  final TextEditingController _rangeController = TextEditingController();

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
        _isLoadingPages = true;
      });

      try {
        final pdfService = ref.read(pdfServiceProvider);
        final count = await pdfService.getPageCount(file);
        setState(() {
          _totalPages = count;
          _isLoadingPages = false;
          _rangeController.text = '1-$count';
        });
      } catch (e) {
        setState(() => _isLoadingPages = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load PDF: $e')),
          );
        }
      }
    }
  }

  Future<void> _processSplit() async {
    if (_selectedFile == null || _totalPages == 0) return;

    List<int> pagesToExtract = [];
    if (_mode == PdfSplitMode.everyPage) {
      pagesToExtract = List.generate(_totalPages, (i) => i + 1);
    } else {
      pagesToExtract = FileUtils.parsePageRange(_rangeController.text, _totalPages);
      if (pagesToExtract.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please specify valid page numbers within document range.')),
        );
        return;
      }
    }

    final allowed = await FreeLimitHelper.checkAndEnforce(
      context: context,
      ref: ref,
      feature: ToolFeature.pdfSplit,
      requestedAmount: pagesToExtract.length,
    );
    if (!allowed) return;

    setState(() => _isProcessing = true);

    try {
      final pdfService = ref.read(pdfServiceProvider);
      final baseName = p.basenameWithoutExtension(_selectedFile!.path);
      final originalBytes = await _selectedFile!.length();

      final outputFiles = await pdfService.splitPdf(
        _selectedFile!,
        pagesToExtract,
        baseName,
      );

      int totalOutputBytes = 0;
      for (final f in outputFiles) {
        if (await f.exists()) {
          totalOutputBytes += await f.length();
        }
      }

      // Record in history
      final historyItem = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        toolName: 'PDF Split',
        title: '$baseName (Split)',
        subtitle: '${outputFiles.length} pages extracted',
        filePaths: outputFiles.map((f) => f.path).toList(),
        originalBytes: originalBytes,
        outputBytes: totalOutputBytes,
        timestamp: DateTime.now(),
      );
      await ref.read(historyProvider.notifier).addHistoryItem(historyItem);
      ref.read(freeUsageManagerProvider).consumeReward(ToolFeature.pdfSplit);
      ref.read(freeUsageManagerProvider).recordFeatureUsage(ToolFeature.pdfSplit);

      await ref.read(adServiceProvider).maybeShowTransitionInterstitial(
        point: AdTransitionPoint.processingComplete,
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        context.pushReplacement(
          RouteConstants.result,
          extra: ProcessingResult(
            success: true,
            feature: ToolFeature.pdfSplit,
            title: 'PDF Split Complete',
            message: 'Extracted ${outputFiles.length} individual pages.',
            outputFiles: outputFiles,
            originalTotalBytes: originalBytes,
            outputTotalBytes: totalOutputBytes,
            repeatRoute: RouteConstants.pdfSplit,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error splitting PDF: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _rangeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return const ProcessingScreen(
        title: 'Splitting PDF...',
        statusMessage: 'Extracting pages locally on your device.',
      );
    }

    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Split PDF',
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
                              Icons.call_split_rounded,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Select PDF to Split',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Extract individual pages or split by custom ranges.',
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
                        // Selected File Card
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
                            subtitle: _isLoadingPages
                                ? const Text('Reading document...')
                                : Text('$_totalPages pages • ${FileUtils.formatBytes(_selectedFile!.lengthSync())}'),
                            trailing: TextButton(
                              onPressed: _pickFile,
                              child: const Text('Change'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Split Options
                        Text(
                          'SPLIT METHOD',
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
                              RadioListTile<PdfSplitMode>(
                                title: const Text('Extract Every Page'),
                                subtitle: Text('Creates $_totalPages separate single-page documents'),
                                value: PdfSplitMode.everyPage,
                                groupValue: _mode,
                                onChanged: (val) => setState(() => _mode = val!),
                              ),
                              const Divider(height: 1),
                              RadioListTile<PdfSplitMode>(
                                title: const Text('Page Range'),
                                subtitle: const Text('E.g. 1-5, 8-12'),
                                value: PdfSplitMode.pageRange,
                                groupValue: _mode,
                                onChanged: (val) => setState(() => _mode = val!),
                              ),
                              const Divider(height: 1),
                              RadioListTile<PdfSplitMode>(
                                title: const Text('Custom Pages'),
                                subtitle: const Text('E.g. 1, 3, 5, 10'),
                                value: PdfSplitMode.customPages,
                                groupValue: _mode,
                                onChanged: (val) => setState(() => _mode = val!),
                              ),
                            ],
                          ),
                        ),
                        if (_mode != PdfSplitMode.everyPage) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: _rangeController,
                            decoration: InputDecoration(
                              labelText: _mode == PdfSplitMode.pageRange
                                  ? 'Enter Range (e.g. 1-3, 5-8)'
                                  : 'Enter Page Numbers (e.g. 1, 3, 5)',
                              hintText: 'Between 1 and $_totalPages',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              helperText: 'Valid page numbers: 1 to $_totalPages',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          if (_selectedFile != null && !_isLoadingPages)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: PrimaryButton(
                label: 'Split PDF',
                icon: Icons.call_split_rounded,
                width: double.infinity,
                onPressed: _processSplit,
              ),
            ),
          if (_selectedFile == null)
            const BannerAdContainer(),
        ],
      ),
    );
  }
}
