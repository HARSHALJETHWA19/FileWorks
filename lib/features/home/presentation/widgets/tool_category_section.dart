import 'package:flutter/material.dart';

class ToolCategorySection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const ToolCategorySection({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 12),
          child: Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            // Adaptive grid columns: 2 columns on phones, 3 or 4 columns on tablets
            final crossAxisCount = constraints.maxWidth > 800
                ? 4
                : constraints.maxWidth > 500
                    ? 3
                    : 2;

            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: children,
            );
          },
        ),
      ],
    );
  }
}
