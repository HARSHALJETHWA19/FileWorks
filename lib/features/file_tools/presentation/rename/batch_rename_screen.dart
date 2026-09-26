import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../shared/models/processing_result.dart';
import '../../../../shared/presentation/processing_screen.dart';
import '../../../../shared/widgets/file_picker_helper.dart';
import '../../../history/models/history_item.dart';
import '../../../history/providers/history_provider.dart';
import '../../../monetization/ad_service.dart';
import '../../../monetization/free_usage_config.dart';
import '../../../monetization/providers/monetization_provider.dart';
import '../../../monetization/services/free_limit_helper.dart';
import '../../providers/file_tools_providers.dart';
import '../../services/rename_service.dart';

class BatchRenameScreen extends ConsumerStatefulWidget {
  const BatchRenameScreen({super.key});

  @override
  ConsumerState<BatchRenameScreen> createState() => _BatchRenameScreenState();
}

class _BatchRenameScreenState extends ConsumerState<BatchRenameScreen> {
  final List<File> _selectedFiles = [];
  final TextEditingController _patternController =
      TextEditingController(text: 'File_{number}');
  final int _startNumber = 1;
  int _padding = 3;
  bool _isProcessing = false;

  List<RenamePreviewItem> _previewItems = [];

  Future<void> _pickFiles() async {
    final files = await FilePickerHelper.pickAnyFiles(allowMultiple: true);
    if (files.isNotEmpty) {
      setState(() {
        _selectedFiles.addAll(files);
      });
      _updatePreview();
    }
  }

  void _updatePreview() {
    if (_selectedFiles.isEmpty) {
      setState(() => _previewItems = []);
      return;
    }
    final renameService = ref.read(renameServiceProvider);
    final items = renameService.generatePreview(
      files: _selectedFiles,
      pattern: _patternController.text.trim(),
      startNumber: _startNumber,
      zeroPadding: _padding,
    );
    setState(() => _previewItems = items);
  }

  Future<void> _processRename() async {
    if (_previewItems.isEmpty) return;

    final allowed = await FreeLimitHelper.checkAndEnforce(
      context: context,
      ref: ref,
      feature: ToolFeature.batchRename,
      requestedAmount: _previewItems.length,
    );
    if (!allowed) return;

    setState(() => _isProcessing = true);

    try {
      final renameService = ref.read(renameServiceProvider);
      final renamedFiles = await renameService.executeBatchRename(_previewItems);

      int totalBytes = 0;
      for (final f in renamedFiles) {
        if (await f.exists()) totalBytes += await f.length();
      }

      // Add to history
      final historyItem = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        toolName: 'Batch Rename',
        title: '${renamedFiles.length} Files Renamed',
        subtitle: 'Pattern: ${_patternController.text.trim()}',
        filePaths: renamedFiles.map((f) => f.path).toList(),
        originalBytes: totalBytes,
        outputBytes: totalBytes,
        timestamp: DateTime.now(),
      );
      await ref.read(historyProvider.notifier).addHistoryItem(historyItem);
      ref.read(freeUsageManagerProvider).consumeReward(ToolFeature.batchRename);
      ref.read(freeUsageManagerProvider).recordFeatureUsage(ToolFeature.batchRename);

      await ref.read(adServiceProvider).maybeShowTransitionInterstitial(
        point: AdTransitionPoint.processingComplete,
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        context.pushReplacement(
          RouteConstants.result,
          extra: ProcessingResult(
            success: true,
            feature: ToolFeature.batchRename,
            title: 'Batch Rename Complete',
            message: 'Renamed ${renamedFiles.length} files successfully.',
            outputFiles: renamedFiles,
            originalTotalBytes: totalBytes,
            outputTotalBytes: totalBytes,
            repeatRoute: RouteConstants.batchRename,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error renaming files: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _patternController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return const ProcessingScreen(
        title: 'Renaming Files...',
        statusMessage: 'Applying new filenames locally on your storage.',
      );
    }

    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Batch Rename',
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
                              Icons.drive_file_rename_outline_rounded,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Select Files to Rename',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Organize and rename multiple files at once using numbering and date patterns.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            label: 'Select Files',
                            icon: Icons.add_circle_outline_rounded,
                            onPressed: _pickFiles,
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      // Configuration Controls
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 12),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _patternController,
                                  decoration: InputDecoration(
                                    labelText: 'Rename Pattern',
                                    hintText: 'e.g. Vacation_{number} or {date}_{name}',
                                    helperText: 'Available tokens: {number}, {date}, {name}',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                  ),
                                  onChanged: (_) => _updatePreview(),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Text('Digits:'),
                                    const SizedBox(width: 8),
                                    SegmentedButton<int>(
                                      segments: const [
                                        ButtonSegment(value: 2, label: Text('01')),
                                        ButtonSegment(value: 3, label: Text('001')),
                                        ButtonSegment(value: 4, label: Text('0001')),
                                      ],
                                      selected: {_padding},
                                      onSelectionChanged: (set) {
                                        setState(() => _padding = set.first);
                                        _updatePreview();
                                      },
                                    ),
                                    const Spacer(),
                                    TextButton.icon(
                                      icon: const Icon(Icons.add_rounded, size: 18),
                                      label: const Text('Add More'),
                                      onPressed: _pickFiles,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Live Preview Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PREVIEW (${_previewItems.length} FILES)',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              'Original → New Name',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Preview List
                      Expanded(
                        child: ListView.builder(
                          itemCount: _previewItems.length,
                          itemBuilder: (context, index) {
                            final item = _previewItems[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.originalName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.colorScheme.onSurfaceVariant,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.newName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _selectedFiles.removeAt(index);
                                        });
                                        _updatePreview();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          if (_previewItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: PrimaryButton(
                label: 'Rename ${_previewItems.length} Files',
                icon: Icons.drive_file_rename_outline_rounded,
                width: double.infinity,
                onPressed: _processRename,
              ),
            ),
        ],
      ),
    );
  }
}
