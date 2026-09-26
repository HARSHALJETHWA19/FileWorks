import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/route_constants.dart';
import '../../core/utils/file_utils.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/primary_button.dart';
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
  @override
  void initState() {
    super.initState();
    // Record operation completed safely without showing an ad on entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adService = ref.read(adServiceProvider);
      adService.recordOperationCompleted();
    });
  }

  Future<void> _triggerAdIfEligible() async {
    final isPro = ref.read(isProProvider);
    if (isPro) return;
    try {
      final adService = ref.read(adServiceProvider);
      await adService.showInterstitialIfReady();
    } catch (_) {
      // Ads must always fail gracefully
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
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
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(30),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green.withAlpha(80), width: 2),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    result.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // File Info Card
                  if (result.hasFiles) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer.withAlpha(120),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    result.totalFilesCount > 1
                                        ? Icons.folder_copy_rounded
                                        : Icons.insert_drive_file_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        result.totalFilesCount > 1
                                            ? '${result.totalFilesCount} files ready'
                                            : (primaryFile != null
                                                ? primaryFile.path.split(Platform.pathSeparator).last
                                                : 'File ready'),
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

                            // Savings details if compressed
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
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
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Action Buttons
                  if (primaryFile != null) ...[
                    PrimaryButton(
                      label: 'Open File',
                      icon: Icons.file_open_rounded,
                      width: double.infinity,
                      onPressed: () => _openFile(context, primaryFile),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Share',
                      icon: Icons.share_rounded,
                      isSecondary: true,
                      width: double.infinity,
                      onPressed: () async {
                        await _shareFiles(context, result.outputFiles);
                        await _triggerAdIfEligible();
                      },
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
                    onPressed: () async {
                      await _triggerAdIfEligible();
                      if (context.mounted) {
                        _handleProcessAnother(context);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
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
                    onPressed: () async {
                      await _triggerAdIfEligible();
                      if (context.mounted) {
                        context.go(RouteConstants.home);
                      }
                    },
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

  void _handleProcessAnother(BuildContext context) {
    try {
      if (widget.result.repeatRoute != null) {
        context.go(widget.result.repeatRoute!);
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go(RouteConstants.home);
      }
    } catch (_) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
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

  Future<void> _shareFiles(BuildContext context, List<File> files) async {
    final xFiles = files.map((f) => XFile(f.path)).toList();
    await SharePlus.instance.share(
      ShareParams(
        files: xFiles,
        text: 'Processed with FileWorks (100% on-device)',
      ),
    );
  }
}
