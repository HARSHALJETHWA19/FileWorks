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
import '../../providers/file_tools_providers.dart';

class ExtractZipScreen extends ConsumerStatefulWidget {
  const ExtractZipScreen({super.key});

  @override
  ConsumerState<ExtractZipScreen> createState() => _ExtractZipScreenState();
}

class _ExtractZipScreenState extends ConsumerState<ExtractZipScreen> {
  File? _selectedZip;
  final TextEditingController _folderController = TextEditingController();
  bool _isProcessing = false;

  Future<void> _pickZip() async {
    final zip = await FilePickerHelper.pickZipFile();
    if (zip != null) {
      setState(() {
        _selectedZip = zip;
        _folderController.text =
            '${p.basenameWithoutExtension(zip.path)}_extracted';
      });
    }
  }

  Future<void> _processExtract() async {
    if (_selectedZip == null) return;

    setState(() => _isProcessing = true);

    try {
      final zipService = ref.read(zipServiceProvider);
      final destFolder = _folderController.text.trim();
      final originalBytes = await _selectedZip!.length();

      final extractedFiles = await zipService.extractZip(
        _selectedZip!,
        customDestDirName: destFolder,
      );

      int totalOutputBytes = 0;
      for (final f in extractedFiles) {
        if (await f.exists()) totalOutputBytes += await f.length();
      }

      final zipName = p.basename(_selectedZip!.path);

      // Add to history
      final historyItem = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        toolName: 'Extract ZIP',
        title: '$zipName (Extracted)',
        subtitle: '${extractedFiles.length} files extracted safely',
        filePaths: extractedFiles.map((f) => f.path).toList(),
        originalBytes: originalBytes,
        outputBytes: totalOutputBytes,
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
                title: 'ZIP Extracted Successfully',
                message: 'Extracted ${extractedFiles.length} files safely on your device.',
                outputFiles: extractedFiles,
                originalTotalBytes: originalBytes,
                outputTotalBytes: totalOutputBytes,
                repeatRoute: RouteConstants.extractZip,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error extracting ZIP: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _folderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return const ProcessingScreen(
        title: 'Extracting ZIP Archive...',
        statusMessage: 'Verifying paths and extracting contents locally.',
      );
    }

    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Extract ZIP',
      body: Column(
        children: [
          Expanded(
            child: _selectedZip == null
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
                              Icons.unarchive_rounded,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Select ZIP Archive to Extract',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Safely unpack compressed archives on your device with complete local privacy.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            label: 'Select ZIP File',
                            icon: Icons.folder_zip_rounded,
                            onPressed: _pickZip,
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
                                Icons.folder_zip_rounded,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              p.basename(_selectedZip!.path),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text('Size: ${FileUtils.formatBytes(_selectedZip!.lengthSync())}'),
                            trailing: TextButton(
                              onPressed: _pickZip,
                              child: const Text('Change'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'DESTINATION FOLDER',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _folderController,
                          decoration: InputDecoration(
                            labelText: 'Folder Name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user_rounded,
                                  size: 20, color: Colors.green),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Zip Slip Defense Active: Malicious relative paths (e.g. "../../") in untrusted archives are automatically blocked.',
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
          if (_selectedZip != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: PrimaryButton(
                label: 'Extract All Files',
                icon: Icons.unarchive_rounded,
                width: double.infinity,
                onPressed: _processExtract,
              ),
            ),
        ],
      ),
    );
  }
}
