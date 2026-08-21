import 'package:flutter/material.dart';

/// Primary action button in the gold accent. Uses the global FilledButton
/// theme (gold fill, marble text, squared corners).
class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
        ],
        Text(label),
      ],
    );

    return SizedBox(
      width: expand ? double.infinity : null,
      child: FilledButton(onPressed: onPressed, child: child),
    );
  }
}