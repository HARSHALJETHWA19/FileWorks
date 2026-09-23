import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../monetization/presentation/banner_ad_widget.dart';
import '../models/history_item.dart';
import '../providers/history_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return AppScaffold(
      title: 'History',
      showBackButton: false,
      actions: [
        if (history.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear History',
            onPressed: () => _confirmClearHistory(context, ref),
          ),
      ],
      body: Column(
        children: [
          Expanded(
            child: history.isEmpty
                ? const EmptyStateView(
                    icon: Icons.history_rounded,
                    title: 'No Recent Activity Yet',
                    message: 'Files you merge, convert, or compress will appear here for easy access.',
                  )
                : ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 20),
                    children: _buildGroupedHistory(context, ref, history),
                  ),
          ),
          const BannerAdContainer(),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedHistory(
    BuildContext context,
    WidgetRef ref,
    List<HistoryItem> items,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayItems = <HistoryItem>[];
    final yesterdayItems = <HistoryItem>[];
    final olderItems = <HistoryItem>[];

    for (final item in items) {
      final itemDate = DateTime(
        item.timestamp.year,
        item.timestamp.month,
        item.timestamp.day,
      );
      if (itemDate == today) {
        todayItems.add(item);
      } else if (itemDate == yesterday) {
        yesterdayItems.add(item);
      } else {
        olderItems.add(item);
      }
    }

    final widgets = <Widget>[];

    if (todayItems.isNotEmpty) {
      widgets.add(_buildSectionHeader(context, 'Today'));
      widgets.addAll(todayItems.map((e) => _buildHistoryCard(context, ref, e)));
    }

    if (yesterdayItems.isNotEmpty) {
      widgets.add(_buildSectionHeader(context, 'Yesterday'));
      widgets.addAll(yesterdayItems.map((e) => _buildHistoryCard(context, ref, e)));
    }

    if (olderItems.isNotEmpty) {
      widgets.add(_buildSectionHeader(context, 'Earlier'));
      widgets.addAll(olderItems.map((e) => _buildHistoryCard(context, ref, e)));
    }

    return widgets;
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, WidgetRef ref, HistoryItem item) {
    final theme = Theme.of(context);
    final timeStr = DateFormat.jm().format(item.timestamp);
    final sizeStr = item.outputBytes > 0 ? FileUtils.formatBytes(item.outputBytes) : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withAlpha(120),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.toolName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  timeStr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => ref.read(historyProvider.notifier).deleteHistoryItem(item.id),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.subtitle.isNotEmpty || sizeStr.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                [item.subtitle, if (sizeStr.isNotEmpty) sizeStr].join(' • '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (item.filePaths.isNotEmpty) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Share', style: TextStyle(fontSize: 13)),
                    onPressed: () => _shareHistoryItem(context, item),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.file_open_rounded, size: 16),
                    label: const Text('Open', style: TextStyle(fontSize: 13)),
                    onPressed: () => _openHistoryItem(context, item),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openHistoryItem(BuildContext context, HistoryItem item) async {
    if (item.filePaths.isEmpty) return;
    final file = File(item.filePaths.first);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File was moved or deleted from device storage.')),
        );
      }
      return;
    }
    await OpenFilex.open(file.path);
  }

  Future<void> _shareHistoryItem(BuildContext context, HistoryItem item) async {
    final existingFiles = <XFile>[];
    for (final path in item.filePaths) {
      if (await File(path).exists()) {
        existingFiles.add(XFile(path));
      }
    }

    if (existingFiles.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File not found on device.')),
        );
      }
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        files: existingFiles,
        text: 'Shared from FileWorks',
      ),
    );
  }

  void _confirmClearHistory(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text(
          'This will remove recent activity records from the app. Your saved files on your device will NOT be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(historyProvider.notifier).clearAll();
              Navigator.of(ctx).pop();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
