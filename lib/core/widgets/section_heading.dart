import 'package:flutter/material.dart';

/// Major section heading in the display (Cinzel) face, with an optional
/// trailing action on the right.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.trailing,
    this.style = 'headlineMedium',
  });

  final String title;
  final Widget? trailing;

  /// One of: display, headline, title — picks the matching text style.
  final String style;

  @override
  Widget build(BuildContext context) {
    final text = Text(title, style: _resolve(context));
    if (trailing == null) return text;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [Expanded(child: text), trailing!],
    );
  }

  TextStyle? _resolve(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return switch (style) {
      'display' => t.headlineLarge,
      'title' => t.titleLarge,
      _ => t.headlineMedium,
    };
  }
}