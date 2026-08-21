import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/muse_colors.dart';
import '../../core/theme/muse_spacing.dart';
import '../../core/widgets/gold_button.dart';
import '../../core/widgets/section_heading.dart';
import 'friends_provider.dart';
import 'pairing_sheet.dart';

/// Pairing — add a device via QR or short pairing code, and manage the friend
/// list. The code exchange is real; the network transport lands in Phase 1.
class PairingScreen extends ConsumerWidget {
  const PairingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final friends = ref.watch(friendsProvider).value ?? const [];

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: MuseSpacing.page,
        vertical: MuseSpacing.lg,
      ),
      children: [
        const SectionHeading(title: 'Pairing'),
        const SizedBox(height: MuseSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(MuseSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pair a new device',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: MuseSpacing.sm),
                Text(
                  'Your device never contacts a server. Exchanging a code '
                  'directly is how two devices become friends.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: MuseSpacing.lg),
                GoldButton(
                  label: 'Show my pairing code',
                  icon: Icons.qr_code_2_rounded,
                  expand: true,
                  onPressed: () => showMyCodeSheet(context),
                ),
                const SizedBox(height: MuseSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => showEnterCodeSheet(context),
                  icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                  label: const Text('Enter a pairing code'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: MuseSpacing.xxl),
        Text('Friends', style: theme.textTheme.titleLarge),
        const SizedBox(height: MuseSpacing.md),
        if (friends.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(MuseSpacing.lg),
              child: Column(
                children: [
                  const SizedBox(height: MuseSpacing.md),
                  Text('No friends yet', style: theme.textTheme.titleSmall),
                  const SizedBox(height: MuseSpacing.xs),
                  Text(
                    'Once paired, your friends appear here and their shared '
                    'music becomes available.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: MuseSpacing.md),
                ],
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < friends.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: MuseSpacing.lg,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: MuseColors.cardSurface,
                      child: Text(
                        friends[i].name.isEmpty
                            ? '?'
                            : friends[i].name[0].toUpperCase(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: MuseColors.gold,
                        ),
                      ),
                    ),
                    title: Text(friends[i].name,
                        style: theme.textTheme.titleSmall),
                    subtitle: Text(
                      '${friends[i].onion.substring(0, 8)}…',
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove friend',
                      icon: const Icon(Icons.person_remove_alt_1_rounded),
                      onPressed: () => ref
                          .read(friendsProvider.notifier)
                          .remove(friends[i].onion),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}