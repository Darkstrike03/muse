import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/muse_spacing.dart';
import '../../core/widgets/section_heading.dart';
import '../library/library_permissions.dart';
import '../library/library_provider.dart';
import 'update_checker.dart';

/// Settings — shell only, plus the music-folder source for the library.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _addFolder(BuildContext context, WidgetRef ref) async {
    final allowed = await ref.read(musicPermissionProvider)();
    if (!allowed) {
      if (!context.mounted) return;
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final folders = ref.watch(musicFoldersProvider).value ?? const [];

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: MuseSpacing.page,
        vertical: MuseSpacing.lg,
      ),
      children: [
        const SectionHeading(title: 'Settings'),
        const SizedBox(height: MuseSpacing.lg),
        Card(
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: MuseSpacing.lg,
                  vertical: MuseSpacing.sm,
                ),
                leading: const Icon(Icons.key_rounded),
                title: Text('Device identity', style: theme.textTheme.titleMedium),
                subtitle: Text(
                  'Keypair not yet generated',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: MuseSpacing.lg,
                  vertical: MuseSpacing.sm,
                ),
                leading: const Icon(Icons.link_rounded),
                title: Text('Pair a device', style: theme.textTheme.titleMedium),
                subtitle: Text(
                  'Show or scan a pairing code',
                  style: theme.textTheme.bodySmall,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(MusePaths.pairing),
              ),
            ],
          ),
        ),
        const SizedBox(height: MuseSpacing.xl),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MuseSpacing.lg,
                  MuseSpacing.lg,
                  MuseSpacing.lg,
                  MuseSpacing.sm,
                ),
                child: Text(
                  'Music folders',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (folders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MuseSpacing.lg,
                  ),
                  child: Text(
                    'No folders yet. Add one to build your library.',
                    style: theme.textTheme.bodySmall,
                  ),
                )
              else
                for (final folder in folders) ...[
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
                    trailing: IconButton(
                      tooltip: 'Remove folder',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => ref
                          .read(musicFoldersProvider.notifier)
                          .remove(folder),
                    ),
                  ),
                  const Divider(height: 1),
                ],
              Padding(
                padding: const EdgeInsets.all(MuseSpacing.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _addFolder(context, ref),
                    icon: const Icon(Icons.create_new_folder_rounded),
                    label: const Text('Add folder'),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MuseSpacing.xl),
        const _UpdateTile(),
      ],
    );
  }
}

/// Version display + manual update check against GitHub Releases. The check
/// only runs when tapped, and the request carries no user data.
class _UpdateTile extends ConsumerStatefulWidget {
  const _UpdateTile();

  @override
  ConsumerState<_UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends ConsumerState<_UpdateTile> {
  bool _checking = false;

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final result = await ref.read(updateCheckerProvider)();
      if (!mounted) return;
      final theme = Theme.of(context);
      if (result.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update check failed: ${result.error}')),
        );
        return;
      }
      if (!result.hasUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Muse ${result.currentVersion} is up to date.'),
          ),
        );
        return;
      }
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Update available'),
          content: Text(
            'Muse ${result.newVersion} is available '
            '(you have ${result.currentVersion}).',
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                openReleasesPage(result.releaseUrl ?? releasesPageUrl);
              },
              child: const Text('Download'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _checking
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.info_outline_rounded),
      title: Text('Check for updates', style: theme.textTheme.titleMedium),
      subtitle: FutureBuilder<String>(
        future: currentAppVersion(),
        initialData: '…',
        builder: (context, snapshot) =>
            Text('Muse v${snapshot.data}', style: theme.textTheme.bodySmall),
      ),
      onTap: _checking ? null : _check,
    );
  }
}