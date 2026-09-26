import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isSecondary;
  final double? width;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isSecondary = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonStyle = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: isSecondary ? theme.colorScheme.secondaryContainer : theme.colorScheme.primary,
      foregroundColor: isSecondary ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onPrimary,
    );

    Widget content;
    if (isLoading) {
      content = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: isSecondary ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onPrimary,
        ),
      );
    } else if (icon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else {
      content = Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      );
    }

    final button = FilledButton(
      style: buttonStyle,
      onPressed: isLoading ? null : onPressed,
      child: content,
    );

    if (width != null) {
      return SizedBox(width: width, child: button);
    }

    return button;
  }
}
