import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/muse_colors.dart';
import '../../core/theme/muse_spacing.dart';
import '../../core/widgets/gold_button.dart';
import 'friends_provider.dart';
import 'identity_provider.dart';

/// The app-level link a device shares so friends can pair with it.
String museLink(String onion, String name) => 'muse://$onion?name=$name';

/// Parses and validates a pairing code. Accepts a bare onion (56 base32
/// chars, optionally with `.onion`) or a full `muse://…` link. Returns the
/// onion and the friend's name (when present), or null when invalid.
({String onion, String? name})? parseMuseCode(String raw) {
  var input = raw.trim();
  var name = null as String?;

  if (input.startsWith('muse://')) {
    final uri = Uri.tryParse(input);
    if (uri == null) return null;
    final host = uri.host.isNotEmpty ? uri.host : uri.path.replaceFirst('/', '');
    final queryName = uri.queryParameters['name'];
    if (host.isEmpty) return null;
    input = host;
    if (queryName != null && queryName.trim().isNotEmpty) {
      name = queryName.trim();
    }
  }

  final cleaned = input.endsWith('.onion')
      ? input.substring(0, input.length - '.onion'.length)
      : input;
  if (!RegExp(r'^[a-z2-7]{56}$').hasMatch(cleaned)) return null;
  return (onion: cleaned, name: name);
}

/// Opens the pair-a-device bottom sheet from the app header: two tabs,
/// one for the pairing actions and one for the friend list.
void openPairingSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const PairingSheet(),
  );
}

/// Two-tab pairing sheet: "Pair a device" (show/enter a code) and "Friends"
/// (the paired-device list). Thin gold tab line matches the rest of the UI.
class PairingSheet extends StatelessWidget {
  const PairingSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SizedBox(
        height: 460,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                labelColor: MuseColors.gold,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                indicatorColor: MuseColors.gold,
                dividerColor: MuseColors.goldHairline,
                tabs: const [
                  Tab(text: 'Pair a device'),
                  Tab(text: 'Friends'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: const [
                    _PairActionsTab(),
                    _FriendsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PairActionsTab extends StatelessWidget {
  const _PairActionsTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MuseSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
    );
  }
}

/// Live friend list with remove, plus an empty state.
class _FriendsTab extends ConsumerWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final friends = ref.watch(friendsProvider).value ?? const [];

    if (friends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(MuseSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No friends yet', style: theme.textTheme.titleSmall),
              const SizedBox(height: MuseSpacing.xs),
              Text(
                'Share your code to pair a device. Once paired, your '
                'friends appear here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: friends.length,
      itemBuilder: (context, i) {
        final friend = friends[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: MuseSpacing.xl,
          ),
          leading: CircleAvatar(
            backgroundColor: MuseColors.cardSurface,
            child: Text(
              friend.name.isEmpty ? '?' : friend.name[0].toUpperCase(),
              style: theme.textTheme.titleSmall?.copyWith(
                color: MuseColors.gold,
              ),
            ),
          ),
          title: Text(friend.name, style: theme.textTheme.titleSmall),
          subtitle: Text(
            '${friend.onion.substring(0, 8)}…',
            style: theme.textTheme.bodySmall,
          ),
          trailing: IconButton(
            tooltip: 'Remove friend',
            icon: const Icon(Icons.person_remove_alt_1_rounded),
            onPressed: () =>
                ref.read(friendsProvider.notifier).remove(friend.onion),
          ),
        );
      },
    );
  }
}

/// Shows a real QR code plus the readable link in a small sheet.
void showMyCodeSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const SafeArea(child: _MyCodeSheet()),
  );
}

class _MyCodeSheet extends ConsumerStatefulWidget {
  const _MyCodeSheet();

  @override
  ConsumerState<_MyCodeSheet> createState() => _MyCodeSheetState();
}

class _MyCodeSheetState extends ConsumerState<_MyCodeSheet> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceId = ref.watch(deviceIdProvider).value ?? '…';
    final deviceName = ref.watch(deviceNameProvider).value ?? 'My Muse';
    final link = museLink(deviceId, deviceName);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(MuseSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Your pairing code', style: theme.textTheme.titleMedium),
          const SizedBox(height: MuseSpacing.lg),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MuseColors.cardSurface,
              border: Border.all(color: MuseColors.goldHairline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: link,
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.transparent,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: MuseColors.gold,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: MuseColors.gold,
              ),
            ),
          ),
          const SizedBox(height: MuseSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  '$deviceId.onion',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    letterSpacing: 1.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: MuseSpacing.xs),
              IconButton(
                tooltip: _copied ? 'Copied' : 'Copy pairing code',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  _copied ? Icons.check_rounded : Icons.copy_rounded,
                  size: 16,
                ),
                color: MuseColors.gold,
                onPressed: () => _copy('$deviceId.onion'),
              ),
              if (_copied) ...[
                const SizedBox(width: MuseSpacing.xs),
                Text('Copied', style: theme.textTheme.bodySmall),
              ],
            ],
          ),
          const SizedBox(height: MuseSpacing.sm),
          Text(
            'Have the other device scan this, or type this code there.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: MuseSpacing.xl),
        ],
      ),
    );
  }
}

void showEnterCodeSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: MuseSpacing.xl,
          right: MuseSpacing.xl,
          top: MuseSpacing.xl,
          bottom: MediaQuery.of(context).viewInsets.bottom + MuseSpacing.xl,
        ),
        child: const EnterCodeSheet(),
      );
    },
  );
}

class EnterCodeSheet extends ConsumerStatefulWidget {
  const EnterCodeSheet({super.key});

  @override
  ConsumerState<EnterCodeSheet> createState() => _EnterCodeSheetState();
}

class _EnterCodeSheetState extends ConsumerState<EnterCodeSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final parsed = parseMuseCode(_controller.text);
    if (parsed == null) {
      setState(() => _error = 'That doesn\'t look like a Muse code.');
      return;
    }
    final myId = await ref.read(deviceIdProvider.future);
    if (parsed.onion == myId) {
      setState(() => _error = 'That\'s your own code.');
      return;
    }
    await ref
        .read(friendsProvider.notifier)
        .add(parsed.onion, parsed.name ?? 'Friend');
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Friend added.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enter a pairing code', style: theme.textTheme.titleMedium),
        const SizedBox(height: MuseSpacing.lg),
        TextField(
          controller: _controller,
          autofocus: true,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(
            hintText: 'muse://… or paste the code',
            prefixIcon: const Icon(Icons.key_rounded),
            errorText: _error,
          ),
        ),
        const SizedBox(height: MuseSpacing.lg),
        GoldButton(
          label: 'Add friend',
          expand: true,
          onPressed: _submit,
        ),
        const SizedBox(height: MuseSpacing.sm),
      ],
    );
  }
}