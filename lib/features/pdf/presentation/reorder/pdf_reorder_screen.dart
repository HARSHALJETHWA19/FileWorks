import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import '../../../../core/constants/route_constants.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../shared/models/processing_result.dart';
import '../../../../shared/presentation/processing_screen.dart';
import '../../../../shared/widgets/file_picker_helper.dart';
import '../../../history/models/history_item.dart';
import '../../../history/providers/history_provider.dart';
import '../../../monetization/free_usage_config.dart';
import '../../../monetization/providers/monetization_provider.dart';
import '../../../monetization/services/free_limit_helper.dart';
import '../../providers/pdf_providers.dart';

class PdfReorderScreen extends ConsumerStatefulWidget {
  const PdfReorderScreen({super.key});

  @override
  ConsumerState<PdfReorderScreen> createState() => _PdfReorderScreenState();
}

class _PdfReorderScreenState extends ConsumerState<PdfReorderScreen> {
  File? _selectedFile;
  List<int> _pageOrder = [];
  bool _isLoading = false;
  bool _isProcessing = false;

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
          _pageOrder = List.generate(count, (i) => i + 1);
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

  Future<void> _processReorder() async {
    if (_selectedFile == null || _pageOrder.isEmpty) return;

    final allowed = await FreeLimitHelper.checkAndEnforce(
      context: context,
      ref: ref,
      feature: ToolFeature.pdfReorder,
      requestedAmount: _pageOrder.length,
    );
    if (!allowed) return;

    setState(() => _isProcessing = true);

    try {
      final pdfService = ref.read(pdfServiceProvider);
      final baseName = p.basenameWithoutExtension(_selectedFile!.path);
      final originalBytes = await _selectedFile!.length();
      final outputName = '${baseName}_reordered.pdf';

      final reorderedFile = await pdfService.reorderPdf(
        _selectedFile!,
        _pageOrder,
        outputName,
      );

      final outputBytes = await reorderedFile.length();

      // Add to history
      final historyItem = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        toolName: 'PDF Reorder',
        title: p.basename(reorderedFile.path),
        subtitle: '${_pageOrder.length} pages reordered',
        filePaths: [reorderedFile.path],
        originalBytes: originalBytes,
        outputBytes: outputBytes,
        timestamp: DateTime.now(),
      );
      await ref.read(historyProvider.notifier).addHistoryItem(historyItem);
      ref.read(freeUsageManagerProvider).consumeReward(ToolFeature.pdfReorder);
      ref.read(freeUsageManagerProvider).recordFeatureUsage(ToolFeature.pdfReorder);

      if (mounted) {
        setState(() => _isProcessing = false);
        context.pushReplacement(
          RouteConstants.result,
          extra: ProcessingResult(
            success: true,
            title: 'PDF Reordered Successfully',
            message: 'All ${_pageOrder.length} pages arranged in your desired sequence.',
            outputFiles: [reorderedFile],
            originalTotalBytes: originalBytes,
            outputTotalBytes: outputBytes,
            repeatRoute: RouteConstants.pdfReorder,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reordering PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return const ProcessingScreen(
        title: 'Reordering PDF...',
        statusMessage: 'Saving pages in new sequence locally.',
      );
    }

    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Reorder PDF',
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
                              Icons.reorder_rounded,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Select PDF to Reorder',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Drag and drop pages to rearrange the order of your document.',
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
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_pageOrder.length} Pages (Drag to rearrange)',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextButton(
                              onPressed: _pickFile,
                              child: const Text('Change File'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ReorderableListView.builder(
                          itemCount: _pageOrder.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final page = _pageOrder.removeAt(oldIndex);
                              _pageOrder.insert(newIndex, page);
                            });
                          },
                          itemBuilder: (context, index) {
                            final pageNum = _pageOrder[index];
                            return Card(
                              key: ValueKey('page_${pageNum}_pos_$index'),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Pos ${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  'Original Page $pageNum',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                trailing: const Icon(Icons.drag_handle_rounded, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          if (_selectedFile != null && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: PrimaryButton(
                label: 'Save Reordered PDF',
                icon: Icons.check_circle_rounded,
                width: double.infinity,
                onPressed: _processReorder,
              ),
            ),
        ],
      ),
    );
  }
}
