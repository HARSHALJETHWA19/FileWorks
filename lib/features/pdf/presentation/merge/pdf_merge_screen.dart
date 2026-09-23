import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../core/utils/file_utils.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../shared/models/processing_result.dart';
import '../../../../shared/presentation/processing_screen.dart';
import '../../../../shared/presentation/result_screen.dart';
import '../../../../shared/widgets/file_picker_helper.dart';
import '../../../history/models/history_item.dart';
import '../../../history/providers/history_provider.dart';
import '../../providers/pdf_providers.dart';

class PdfMergeScreen extends ConsumerStatefulWidget {
  const PdfMergeScreen({super.key});

  @override
  ConsumerState<PdfMergeScreen> createState() => _PdfMergeScreenState();
}

class _PdfMergeScreenState extends ConsumerState<PdfMergeScreen> {
  final List<File> _selectedFiles = [];
  final TextEditingController _nameController =
      TextEditingController(text: 'merged_document.pdf');
  bool _isProcessing = false;

  Future<void> _pickFiles() async {
    final files = await FilePickerHelper.pickPdfFiles(allowMultiple: true);
    if (files.isNotEmpty) {
      setState(() {
        _selectedFiles.addAll(files);
      });
    }
  }

  Future<void> _processMerge() async {
    if (_selectedFiles.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 2 PDF files to merge.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final pdfService = ref.read(pdfServiceProvider);
      final outputName = _nameController.text.trim().isEmpty
          ? 'merged_document.pdf'
          : _nameController.text.trim();

      int originalTotalBytes = 0;
      for (final f in _selectedFiles) {
        if (await f.exists()) {
          originalTotalBytes += await f.length();
        }
      }

      final mergedFile = await pdfService.mergePdfs(_selectedFiles, outputName);
      final outputBytes = await mergedFile.length();

      // Add to local history
      final historyItem = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        toolName: 'PDF Merge',
        title: p.basename(mergedFile.path),
        subtitle: '${_selectedFiles.length} PDFs merged',
        filePaths: [mergedFile.path],
        originalBytes: originalTotalBytes,
        outputBytes: outputBytes,
        timestamp: DateTime.now(),
      );
      await ref.read(historyProvider.notifier).addHistoryItem(historyItem);

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              result: ProcessingResult(
                success: true,
                title: 'PDFs Merged Successfully',
                message: '${_selectedFiles.length} documents combined into one.',
                outputFiles: [mergedFile],
                originalTotalBytes: originalTotalBytes,
                outputTotalBytes: outputBytes,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error merging PDFs: $e')),
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
        title: 'Merging PDFs...',
        statusMessage: 'Combining your documents locally. Please wait.',
      );
    }

    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Merge PDF',
      body: Column(
        children: [
          Expanded(
            child: _selectedFiles.isEmpty
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
                              Icons.call_merge_rounded,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Select PDFs to Merge',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Combine two or more PDF files into a single document.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            label: 'Select PDF Files',
                            icon: Icons.add_circle_outline_rounded,
                            onPressed: _pickFiles,
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
                              '${_selectedFiles.length} Files (Drag to reorder)',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextButton.icon(
                              onPressed: _pickFiles,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add More'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ReorderableListView.builder(
                          itemCount: _selectedFiles.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = _selectedFiles.removeAt(oldIndex);
                              _selectedFiles.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final file = _selectedFiles[index];
                            final fileName = p.basename(file.path);
                            final fileSize = file.existsSync()
                                ? FileUtils.formatBytes(file.lengthSync())
                                : '';

                            return Card(
                              key: ValueKey(file.path + index.toString()),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(fileSize),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _selectedFiles.removeAt(index);
                                        });
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
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Output Filename',
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
          if (_selectedFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: PrimaryButton(
                label: 'Merge ${_selectedFiles.length} PDFs',
                icon: Icons.call_merge_rounded,
                width: double.infinity,
                onPressed: _processMerge,
              ),
            ),
        ],
      ),
    );
  }
}
