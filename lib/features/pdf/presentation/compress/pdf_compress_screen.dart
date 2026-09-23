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
import '../../models/pdf_models.dart';
import '../../providers/pdf_providers.dart';

class PdfCompressScreen extends ConsumerStatefulWidget {
  const PdfCompressScreen({super.key});

  @override
  ConsumerState<PdfCompressScreen> createState() => _PdfCompressScreenState();
}

class _PdfCompressScreenState extends ConsumerState<PdfCompressScreen> {
  File? _selectedFile;
  int _originalSize = 0;
  bool _isProcessing = false;
  PdfCompressQuality _quality = PdfCompressQuality.balanced;

  Future<void> _pickFile() async {
    final file = await FilePickerHelper.pickSinglePdfFile();
    if (file != null) {
      final size = await file.length();
      setState(() {
        _selectedFile = file;
        _originalSize = size;
      });
    }
  }

  Future<void> _processCompress() async {
    if (_selectedFile == null) return;

    setState(() => _isProcessing = true);

    try {
      final pdfService = ref.read(pdfServiceProvider);
      final baseName = p.basenameWithoutExtension(_selectedFile!.path);
      final outputName = '${baseName}_compressed.pdf';

      final compressedFile = await pdfService.compressPdf(
        _selectedFile!,
        _quality,
        outputName,
      );

      final outputBytes = await compressedFile.length();
      final savings = FileUtils.calculateSavings(_originalSize, outputBytes);

      // Record in history
      final historyItem = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        toolName: 'PDF Compress',
        title: p.basename(compressedFile.path),
        subtitle: savings > 0
            ? '${savings.toStringAsFixed(1)}% size saved'
            : 'Optimized PDF structure',
        filePaths: [compressedFile.path],
        originalBytes: _originalSize,
        outputBytes: outputBytes,
        timestamp: DateTime.now(),
      );
      await ref.read(historyProvider.notifier).addHistoryItem(historyItem);

      if (mounted) {
        setState(() => _isProcessing = false);

        String message;
        if (outputBytes < _originalSize) {
          message = 'Reduced file size by ${savings.toStringAsFixed(1)}%.';
        } else {
          message = 'The PDF was already well-compressed. Structure has been optimized.';
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              result: ProcessingResult(
                success: true,
                title: 'PDF Compression Complete',
                message: message,
                outputFiles: [compressedFile],
                originalTotalBytes: _originalSize,
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
          SnackBar(content: Text('Error compressing PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return const ProcessingScreen(
        title: 'Compressing PDF...',
        statusMessage: 'Optimizing PDF streams locally on your device.',
      );
    }

    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Compress PDF',
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
                              Icons.compress_rounded,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Select PDF to Compress',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Reduce PDF document size without uploading to any server.',
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
                            subtitle: Text('Original: ${FileUtils.formatBytes(_originalSize)}'),
                            trailing: TextButton(
                              onPressed: _pickFile,
                              child: const Text('Change'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'COMPRESSION LEVEL',
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
                              RadioListTile<PdfCompressQuality>(
                                title: const Text('Balanced (Recommended)'),
                                subtitle: const Text('Standard compression with great visual clarity'),
                                value: PdfCompressQuality.balanced,
                                groupValue: _quality,
                                onChanged: (val) => setState(() => _quality = val!),
                              ),
                              const Divider(height: 1),
                              RadioListTile<PdfCompressQuality>(
                                title: const Text('High Quality'),
                                subtitle: const Text('Minimal compression, best for graphics and text'),
                                value: PdfCompressQuality.highQuality,
                                groupValue: _quality,
                                onChanged: (val) => setState(() => _quality = val!),
                              ),
                              const Divider(height: 1),
                              RadioListTile<PdfCompressQuality>(
                                title: const Text('Maximum Compression'),
                                subtitle: const Text('Smallest possible file size'),
                                value: PdfCompressQuality.maximumCompression,
                                groupValue: _quality,
                                onChanged: (val) => setState(() => _quality = val!),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  size: 18, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Compression results depend on the embedded elements of your PDF. Files that already contain compressed images will see modest changes.',
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
          if (_selectedFile != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: PrimaryButton(
                label: 'Compress PDF',
                icon: Icons.compress_rounded,
                width: double.infinity,
                onPressed: _processCompress,
              ),
            ),
        ],
      ),
    );
  }
}
