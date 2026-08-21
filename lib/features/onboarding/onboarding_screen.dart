import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/muse_spacing.dart';
import '../../core/widgets/gold_button.dart';
import '../../core/widgets/meander_divider.dart';
import '../../core/widgets/medallion_art.dart';
import '../../core/widgets/muse_hero_frame.dart';
import '../../shared/state/app_state.dart';
import '../library/library_permissions.dart';
import '../library/library_provider.dart';

/// First-launch hero flow in two steps: the identity pitch, then choosing at
/// least one music folder so the app is never empty. Onboarding only
/// completes once a folder has been added; more can be added later in
/// Settings.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;

  Future<void> _addFolder() async {
    final allowed = await ref.read(musicPermissionProvider)();
    if (!allowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Storage access is needed to read your music.'),
        ),
      );
      return;
    }
    final pick = ref.read(pickMusicFolderProvider);
    final dir = await pick();
    if (dir == null || dir.isEmpty) return;
    await ref.read(musicFoldersProvider.notifier).add(dir);
  }

  Future<void> _enter() async {
    await ref.read(onboardingDoneProvider.notifier).complete();
    if (!mounted) return;
    context.go(MusePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folders = ref.watch(musicFoldersProvider).value ?? const [];

    return Scaffold(
      body: MuseHeroFrame(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MuseSpacing.xl,
              vertical: MuseSpacing.xl,
            ),
            child: Column(
              children: _step == 0
                  ? _stepOne(theme)
                  : _stepTwo(theme, folders),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _stepOne(ThemeData theme) {
    return [
      Text(
        'muse',
        textAlign: TextAlign.center,
        style: theme.textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: MuseSpacing.lg),
      Text(
        'your music, kept to yourself',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: MuseSpacing.xl),
      const MeanderDivider(height: 18),
      const SizedBox(height: MuseSpacing.xl),
      Text(
        'No account. No cloud. Two devices paired directly — '
        'sharing music peer-to-peer, with nothing in between.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: MuseSpacing.xxxl),
      GoldButton(
        label: 'Get started',
        icon: Icons.arrow_forward_rounded,
        onPressed: () => setState(() => _step = 1),
      ),
      const SizedBox(height: MuseSpacing.xl),
      Text(
        'no login  ·  no server  ·  just your music',
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall,
      ),
    ];
  }

  List<Widget> _stepTwo(ThemeData theme, List<String> folders) {
    return [
      MedallionArt(size: 72, placeholder: const Icon(Icons.library_music)),
      const SizedBox(height: MuseSpacing.lg),
      Text(
        'your music, on your device',
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: MuseSpacing.md),
      Text(
        'Muse plays the files on your device. Choose at least one '
        'music folder to start — you can add more later in Settings.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: MuseSpacing.xl),
      if (folders.isNotEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: MuseSpacing.sm),
            child: Column(
              children: [
                for (final folder in folders.take(3))
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: MuseSpacing.lg,
                    ),
                    leading: const Icon(Icons.folder_rounded),
                    title: Text(
                      folder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                if (folders.length > 3)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MuseSpacing.lg,
                    ),
                    child: Text(
                      '+${folders.length - 3} more',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
          ),
        )
      else
        Text(
          'No folder chosen yet.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      const SizedBox(height: MuseSpacing.lg),
      GoldButton(
        label: 'Add folder',
        icon: Icons.create_new_folder_rounded,
        onPressed: _addFolder,
      ),
      const SizedBox(height: MuseSpacing.md),
      GoldButton(
        label: 'Enter Muse',
        icon: Icons.arrow_forward_rounded,
        onPressed: folders.isEmpty ? null : _enter,
      ),
    ];
  }
}