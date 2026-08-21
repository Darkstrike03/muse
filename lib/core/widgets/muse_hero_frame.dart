import 'package:flutter/material.dart';

import '../theme/muse_spacing.dart';
import 'column_divider.dart';
import 'pediment.dart';

/// Frame for hero/anchor screens (onboarding, now playing).
///
/// Adds the pediment triangle at the top and, optionally, Doric columns
/// flanking the content. This motif set is restricted to hero screens —
/// Home/Library/Settings must not use it.
class MuseHeroFrame extends StatelessWidget {
  const MuseHeroFrame({
    super.key,
    required this.child,
    this.showColumns = true,
    this.pedimentWidth = 260,
    this.columnsTopInset,
  });

  final Widget child;
  final bool showColumns;
  final double pedimentWidth;

  /// When set, the flanking Doric columns sit at the top of the frame pushed
  /// down by this inset. When null they are centered vertically.
  final double? columnsTopInset;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        const SizedBox(height: MuseSpacing.xl),
        Pediment(width: pedimentWidth),
        const SizedBox(height: MuseSpacing.lg),
        Expanded(child: child),
      ],
    );

    if (!showColumns) {
      return content;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          mainAxisAlignment: columnsTopInset == null
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            if (columnsTopInset != null)
              SizedBox(height: columnsTopInset),
            const ColumnDivider(height: 245),
          ],
        ),
        const SizedBox(width: MuseSpacing.md),
        Expanded(child: content),
        const SizedBox(width: MuseSpacing.md),
        Column(
          mainAxisAlignment: columnsTopInset == null
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            if (columnsTopInset != null)
              SizedBox(height: columnsTopInset),
            const ColumnDivider(height: 245),
          ],
        ),
      ],
    );
  }
}