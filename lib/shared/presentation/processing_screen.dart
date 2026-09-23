import 'package:flutter/material.dart';
import '../../core/widgets/privacy_badge.dart';

class ProcessingScreen extends StatelessWidget {
  final String title;
  final String statusMessage;
  final double? progress; // 0.0 to 1.0, null for indeterminate
  final VoidCallback? onCancel;

  const ProcessingScreen({
    super.key,
    this.title = 'Processing...',
    this.statusMessage = 'Working on your files locally...',
    this.progress,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const PrivacyBadge(compact: true),
                  const SizedBox(height: 36),
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withAlpha(80),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: progress != null
                            ? CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 4,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              )
                            : const CircularProgressIndicator(strokeWidth: 4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    statusMessage,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (progress != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(progress! * 100).toInt()}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                  if (onCancel != null) ...[
                    const SizedBox(height: 32),
                    TextButton(
                      onPressed: onCancel,
                      child: const Text('Cancel Operation'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
