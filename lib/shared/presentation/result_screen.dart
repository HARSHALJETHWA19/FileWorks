import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/constants/route_constants.dart';
import '../../core/services/file_save_service.dart';
import '../../core/utils/file_utils.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/primary_button.dart';
import '../../features/monetization/ad_service.dart';
import '../../features/monetization/presentation/banner_ad_widget.dart';
import '../../features/monetization/providers/monetization_provider.dart';
import '../models/processing_result.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final ProcessingResult result;

  const ResultScreen({super.key, required this.result});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    // Record operation completed safely without showing an ad on entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adService = ref.read(adServiceProvider);
      adService.recordOperationCompleted();
    });
  }

  Future<void> _triggerAdIfEligible(AdTransitionPoint point) async {
    final isPro = ref.read(isProProvider);
    if (isPro) return;
    try {
      final adService = ref.read(adServiceProvider);
      await adService.maybeShowTransitionInterstitial(point: point).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          debugPrint('Interstitial timeout on transition ($point)');
          return false;
        },
      );
    } catch (e) {
      debugPrint('Ad trigger error: $e');
    }
  }

  void _handleDone(BuildContext context) {
    if (!context.mounted) return;
    try {
      context.go(RouteConstants.home);
    } catch (_) {
      try {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } catch (_) {}
    }
  }

  void _handleProcessAnother(BuildContext context) {
    if (!context.mounted) return;
    try {
      if (widget.result.repeatRoute != null) {
        context.go(widget.result.repeatRoute!);
      } else {
        context.go(RouteConstants.home);
      }
    } catch (_) {
      try {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } catch (_) {}
    }
  }

  Future<void> _onDonePressed(BuildContext context) async {
    if (_isNavigating) return;
    _isNavigating = true;
    await _triggerAdIfEligible(AdTransitionPoint.doneNavigation);
    if (context.mounted) {
      _handleDone(context);
    }
  }

  Future<void> _onProcessAnotherPressed(BuildContext context) async {
    if (_isNavigating) return;
    _isNavigating = true;
    await _triggerAdIfEligible(AdTransitionPoint.processAnotherFile);
    if (context.mounted) {
      _handleProcessAnother(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
    final isMultiFile = result.outputFiles.length > 1;
    final primaryFile = result.primaryFile;

    return AppScaffold(
      title: 'Result',
      showBackButton: false,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Success Animated Icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(30),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green.withAlpha(80), width: 2),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    result.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    result.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Single File Card or Multi-File Card
                  if (result.hasFiles) ...[
                    if (!isMultiFile && primaryFile != null)
                      _buildSingleFileInfoCard(theme, primaryFile, result)
                    else
                      _buildMultiFilesCard(theme, result),
                    const SizedBox(height: 24),
                  ],

                  // Action Buttons
                  if (!isMultiFile && primaryFile != null) ...[
                    PrimaryButton(
                      label: 'Open File',
                      icon: Icons.file_open_rounded,
                      width: double.infinity,
                      onPressed: () => _openFile(context, primaryFile),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Save to Device',
                      icon: Icons.save_alt_rounded,
                      isSecondary: true,
                      width: double.infinity,
                      onPressed: () => _saveFileToDevice(context, primaryFile),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Share',
                      icon: Icons.share_rounded,
                      isSecondary: true,
                      width: double.infinity,
                      onPressed: () => _shareFiles(context, result.outputFiles),
                    ),
                    const SizedBox(height: 12),
                  ] else if (isMultiFile) ...[
                    if (result.isExtractZip) ...[
                      PrimaryButton(
                        label: 'Save All Files',
                        icon: Icons.download_rounded,
                        width: double.infinity,
                        onPressed: () => _saveAllFilesIndividually(context, result.outputFiles),
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Save as ZIP',
                        icon: Icons.folder_zip_rounded,
                        isSecondary: true,
                        width: double.infinity,
                        onPressed: () => _saveAllAsZip(context, result.outputFiles),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      PrimaryButton(
                        label: 'Save All to Device (ZIP)',
                        icon: Icons.folder_zip_rounded,
                        width: double.infinity,
                        onPressed: () => _saveAllAsZip(context, result.outputFiles),
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Save All Files',
                        icon: Icons.download_rounded,
                        isSecondary: true,
                        width: double.infinity,
                        onPressed: () => _saveAllFilesIndividually(context, result.outputFiles),
                      ),
                      const SizedBox(height: 12),
                    ],
                    PrimaryButton(
                      label: 'Share All (${result.totalFilesCount} files)',
                      icon: Icons.share_rounded,
                      isSecondary: true,
                      width: double.infinity,
                      onPressed: () => _shareFiles(context, result.outputFiles),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Process Another File button
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text(
                      'Process Another File',
                      semanticsLabel: 'Process Another File',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    onPressed: () => _onProcessAnotherPressed(context),
                  ),
                  const SizedBox(height: 12),

                  // Done Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text(
                      'Done',
                      semanticsLabel: 'Done and return home',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    onPressed: () => _onDonePressed(context),
                  ),
                ],
              ),
            ),
          ),
          const BannerAdContainer(),
        ],
      ),
    );
  }

  Widget _buildSingleFileInfoCard(ThemeData theme, File file, ProcessingResult result) {
    final fileName = p.basename(file.path);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withAlpha(140),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getFileIcon(fileName),
                    color: theme.colorScheme.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.outputTotalBytes > 0
                            ? FileUtils.formatBytes(result.outputTotalBytes)
                            : (file.existsSync() ? FileUtils.formatBytes(file.lengthSync()) : ''),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (result.savingsPercentage > 0) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatColumn(
                    theme,
                    'Original',
                    FileUtils.formatBytes(result.originalTotalBytes),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                  _buildStatColumn(
                    theme,
                    'Optimized',
                    FileUtils.formatBytes(result.outputTotalBytes),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withAlpha(80)),
                    ),
                    child: Text(
                      '-${result.savingsPercentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMultiFilesCard(ThemeData theme, ProcessingResult result) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withAlpha(140),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.folder_copy_rounded,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${result.totalFilesCount} files ready',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      Text(
                        result.outputTotalBytes > 0
                            ? 'Total size: ${FileUtils.formatBytes(result.outputTotalBytes)}'
                            : '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              'OUTPUT FILES',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: result.outputFiles.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final file = result.outputFiles[index];
                final fileName = p.basename(file.path);
                final fileSize = file.existsSync() ? FileUtils.formatBytes(file.lengthSync()) : '';

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  leading: Icon(
                    _getFileIcon(fileName),
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                  title: Text(
                    fileName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(fileSize, style: theme.textTheme.bodySmall),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.file_open_rounded, size: 20),
                        tooltip: 'Open',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _openFile(context, file),
                      ),
                      IconButton(
                        icon: const Icon(Icons.download_rounded, size: 20),
                        tooltip: 'Save',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _saveFileToDevice(context, file),
                      ),
                    ],
                  ),
                  onTap: () => _openFile(context, file),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String filename) {
    final ext = p.extension(filename).toLowerCase();
    switch (ext) {
      case '.pdf':
        return Icons.picture_as_pdf_rounded;
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.webp':
        return Icons.image_rounded;
      case '.zip':
        return Icons.folder_zip_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Widget _buildStatColumn(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ],
    );
  }

  Future<void> _openFile(BuildContext context, File file) async {
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File not found.')),
        );
      }
      return;
    }
    await OpenFilex.open(file.path);
  }

  Future<void> _saveFileToDevice(BuildContext context, File file) async {
    final fileName = p.basename(file.path);
    final res = await FileSaveService.saveFileToDevice(file: file);
    if (!context.mounted) return;
    if (res.status == FileSaveStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "$fileName" to device successfully.'),
          backgroundColor: Colors.green.shade800,
        ),
      );
      await _triggerAdIfEligible(AdTransitionPoint.saveToDeviceComplete);
    } else if (res.status == FileSaveStatus.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save "$fileName": ${res.errorMessage ?? "Unknown error"}'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _saveAllAsZip(BuildContext context, List<File> files) async {
    final cleanTitle = FileUtils.sanitizeFilename(
      widget.result.title.toLowerCase().replaceAll(' ', '_'),
    );
    final defaultZipName = '$cleanTitle.zip';
    final res = await FileSaveService.saveMultipleFilesAsZipToDevice(
      files: files,
      zipFileName: defaultZipName,
    );
    if (!context.mounted) return;
    if (res.status == FileSaveStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved all files to device as "$defaultZipName".'),
          backgroundColor: Colors.green.shade800,
        ),
      );
      await _triggerAdIfEligible(AdTransitionPoint.saveToDeviceComplete);
    } else if (res.status == FileSaveStatus.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save archive: ${res.errorMessage ?? "Unknown error"}'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _saveAllFilesIndividually(BuildContext context, List<File> files) async {
    final res = await FileSaveService.saveAllFilesIndividually(files: files);
    if (!context.mounted) return;

    if (res.isAllSuccessful) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully saved all ${res.savedCount} files to device.'),
          backgroundColor: Colors.green.shade800,
        ),
      );
      await _triggerAdIfEligible(AdTransitionPoint.saveToDeviceComplete);
    } else if (res.wasCancelled && res.savedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved ${res.savedCount} of ${res.totalCount} files (cancelled remaining).'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      await _triggerAdIfEligible(AdTransitionPoint.saveToDeviceComplete);
    } else if (res.wasCancelled && res.savedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save cancelled.'),
        ),
      );
    } else if (res.failedCount > 0 && res.savedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved ${res.savedCount} files, ${res.failedCount} failed.'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      await _triggerAdIfEligible(AdTransitionPoint.saveToDeviceComplete);
    } else if (res.isAllFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save files: ${res.failedFileNames.isNotEmpty ? res.failedFileNames.join(", ") : res.errorMessage ?? "Unknown error"}',
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _shareFiles(BuildContext context, List<File> files) async {
    final xFiles = files.map((f) => XFile(f.path)).toList();
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    await SharePlus.instance.share(
      ShareParams(
        files: xFiles,
        text: 'Processed with FileWorks (100% on-device)',
        sharePositionOrigin: origin,
      ),
    );
  }
}
