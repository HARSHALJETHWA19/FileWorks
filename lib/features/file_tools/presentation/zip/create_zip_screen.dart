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
import '../../../monetization/free_usage_config.dart';
import '../../../monetization/providers/monetization_provider.dart';
import '../../../monetization/services/free_limit_helper.dart';
import '../../providers/file_tools_providers.dart';

class CreateZipScreen extends ConsumerStatefulWidget {
  const CreateZipScreen({super.key});

  @override
  ConsumerState<CreateZipScreen> createState() => _CreateZipScreenState();
}

class _CreateZipScreenState extends ConsumerState<CreateZipScreen> {
  final List<File> _selectedFiles = [];
  final TextEditingController _nameController =
      TextEditingController(text: 'archive.zip');
  bool _isProcessing = false;

  Future<void> _pickFiles() async {
    final files = await FilePickerHelper.pickAnyFiles(allowMultiple: true);
    if (files.isNotEmpty) {
      setState(() {
        _selectedFiles.addAll(files);
      });
    }
  }

  Future<void> _processZip() async {
    if (_selectedFiles.isEmpty) return;

    final allowed = await FreeLimitHelper.checkAndEnforce(
      context: context,
      ref: ref,
      feature: ToolFeature.createZip,
      requestedAmount: _selectedFiles.length,
    );
    if (!allowed) return;

    setState(() => _isProcessing = true);

    try {
      final zipService = ref.read(zipServiceProvider);
      final outputName = _nameController.text.trim().isEmpty
          ? 'archive.zip'
          : _nameController.text.trim();

      int originalTotalBytes = 0;
      for (final f in _selectedFiles) {
        if (await f.exists()) originalTotalBytes += await f.length();
      }

      final zipFile = await zipService.createZip(_selectedFiles, outputName);
      final outputBytes = await zipFile.length();

      // Add to history
      final historyItem = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        toolName: 'Create ZIP',
        title: p.basename(zipFile.path),
        subtitle: '${_selectedFiles.length} files compressed',
        filePaths: [zipFile.path],
        originalBytes: originalTotalBytes,
        outputBytes: outputBytes,
        timestamp: DateTime.now(),
      );
      await ref.read(historyProvider.notifier).addHistoryItem(historyItem);
      ref.read(freeUsageManagerProvider).consumeReward(ToolFeature.createZip);
      ref.read(freeUsageManagerProvider).recordFeatureUsage(ToolFeature.createZip);

      if (mounted) {
        setState(() => _isProcessing = false);
        context.pushReplacement(
          RouteConstants.result,
          extra: ProcessingResult(
            success: true,
            title: 'ZIP Archive Created',
            message: 'Compressed ${_selectedFiles.length} files into an archive.',
            outputFiles: [zipFile],
            originalTotalBytes: originalTotalBytes,
            outputTotalBytes: outputBytes,
            repeatRoute: RouteConstants.createZip,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating ZIP: $e')),
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
        title: 'Creating ZIP Archive...',
        statusMessage: 'Compressing files into an archive locally.',
      );
    }

    final theme = Theme.of(context);

    int totalBytes = 0;
    for (final f in _selectedFiles) {
      if (f.existsSync()) totalBytes += f.lengthSync();
    }

    return AppScaffold(
      title: 'Create ZIP',
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
                              Icons.folder_zip_rounded,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Select Files to Archive',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Package documents, photos, or data into a standard .zip archive.',
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
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_selectedFiles.length} Files (${FileUtils.formatBytes(totalBytes)})',
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
                        child: ListView.builder(
                          itemCount: _selectedFiles.length,
                          itemBuilder: (context, index) {
                            final file = _selectedFiles[index];
                            final name = p.basename(file.path);
                            final sizeStr = file.existsSync()
                                ? FileUtils.formatBytes(file.lengthSync())
                                : '';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  Icons.insert_drive_file_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                                title: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(sizeStr),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () {
                                    setState(() => _selectedFiles.removeAt(index));
                                  },
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
                            labelText: 'Archive Name',
                            suffixText: '.zip',
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
                label: 'Create ZIP (${_selectedFiles.length} Files)',
                icon: Icons.folder_zip_rounded,
                width: double.infinity,
                onPressed: _processZip,
              ),
            ),
        ],
      ),
    );
  }
}
