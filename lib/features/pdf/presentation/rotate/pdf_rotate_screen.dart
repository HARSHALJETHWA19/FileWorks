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
import '../../providers/pdf_providers.dart';

class PdfRotateScreen extends ConsumerStatefulWidget {
  const PdfRotateScreen({super.key});

  @override
  ConsumerState<PdfRotateScreen> createState() => _PdfRotateScreenState();
}

class _PdfRotateScreenState extends ConsumerState<PdfRotateScreen> {
  File? _selectedFile;
  int _totalPages = 0;
  bool _isLoading = false;
  bool _isProcessing = false;

  int _selectedAngle = 90; // 90, 180, 270
  String _applyScope = 'all'; // 'all', 'odd', 'even', 'custom'
  final TextEditingController _customPagesController = TextEditingController();

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

  Future<void> _processRotate() async {
    if (_selectedFile == null || _totalPages == 0) return;

    final rotations = <int, int>{};
    for (int i = 1; i <= _totalPages; i++) {
      bool shouldRotate = false;
      if (_applyScope == 'all') {
        shouldRotate = true;
      } else if (_applyScope == 'odd' && i.isOdd) {
        shouldRotate = true;
      } else if (_applyScope == 'even' && i.isEven) {
        shouldRotate = true;
      } else if (_applyScope == 'custom') {
        final customPages = FileUtils.parsePageRange(_customPagesController.text, _totalPages);
        shouldRotate = customPages.contains(i);
      }

      if (shouldRotate) {
        rotations[i] = _selectedAngle;
      }
    }

    if (rotations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pages selected for rotation.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final pdfService = ref.read(pdfServiceProvider);
      final baseName = p.basenameWithoutExtension(_selectedFile!.path);
      final originalBytes = await _selectedFile!.length();
      final outputName = '${baseName}_rotated.pdf';

      final rotatedFile = await pdfService.rotatePdf(
        _selectedFile!,
        rotations,
        outputName,
      );

      final outputBytes = await rotatedFile.length();

      // Add to history
      final historyItem = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        toolName: 'PDF Rotate',
        title: p.basename(rotatedFile.path),
        subtitle: '${rotations.length} pages rotated $_selectedAngle°',
        filePaths: [rotatedFile.path],
        originalBytes: originalBytes,
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
                title: 'PDF Rotated Successfully',
                message: '${rotations.length} pages rotated by $_selectedAngle°.',
                outputFiles: [rotatedFile],
                originalTotalBytes: originalBytes,
                outputTotalBytes: outputBytes,
                repeatRoute: RouteConstants.pdfRotate,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rotating PDF: $e')),
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
      return const ProcessingScreen(
        title: 'Rotating PDF...',
        statusMessage: 'Rotating document pages locally.',
      );
    }

    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Rotate PDF',
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
                              Icons.rotate_right_rounded,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Select PDF to Rotate',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Rotate all pages or specific pages by 90°, 180°, or 270°.',
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
                                ? const Text('Reading document...')
                                : Text('$_totalPages pages • ${FileUtils.formatBytes(_selectedFile!.lengthSync())}'),
                            trailing: TextButton(
                              onPressed: _pickFile,
                              child: const Text('Change'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Rotation Angle Selector
                        Text(
                          'ROTATION ANGLE',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 90, label: Text('90° Right')),
                            ButtonSegment(value: 180, label: Text('180°')),
                            ButtonSegment(value: 270, label: Text('90° Left')),
                          ],
                          selected: {_selectedAngle},
                          onSelectionChanged: (set) =>
                              setState(() => _selectedAngle = set.first),
                        ),
                        const SizedBox(height: 24),

                        // Scope Selector
                        Text(
                          'PAGES TO ROTATE',
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
                                value: 'all',
                                groupValue: _applyScope,
                                onChanged: (val) => setState(() => _applyScope = val!),
                              ),
                              const Divider(height: 1),
                              RadioListTile<String>(
                                title: const Text('Odd Pages Only'),
                                subtitle: const Text('Pages 1, 3, 5...'),
                                value: 'odd',
                                groupValue: _applyScope,
                                onChanged: (val) => setState(() => _applyScope = val!),
                              ),
                              const Divider(height: 1),
                              RadioListTile<String>(
                                title: const Text('Even Pages Only'),
                                subtitle: const Text('Pages 2, 4, 6...'),
                                value: 'even',
                                groupValue: _applyScope,
                                onChanged: (val) => setState(() => _applyScope = val!),
                              ),
                              const Divider(height: 1),
                              RadioListTile<String>(
                                title: const Text('Custom Range'),
                                subtitle: const Text('Specify pages to rotate'),
                                value: 'custom',
                                groupValue: _applyScope,
                                onChanged: (val) => setState(() => _applyScope = val!),
                              ),
                            ],
                          ),
                        ),
                        if (_applyScope == 'custom') ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: _customPagesController,
                            decoration: InputDecoration(
                              labelText: 'Page numbers (e.g. 1, 3-5)',
                              hintText: 'Enter page numbers',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          if (_selectedFile != null && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: PrimaryButton(
                label: 'Rotate PDF',
                icon: Icons.rotate_right_rounded,
                width: double.infinity,
                onPressed: _processRotate,
              ),
            ),
        ],
      ),
    );
  }
}
