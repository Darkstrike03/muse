import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/muse_colors.dart';
import '../../shared/state/app_state.dart';

/// Brief launch screen. Waits for the persisted first-launch flag, then
/// routes to onboarding (first run) or the main shell (returning user).
/// Shows the app mark centered on the marble canvas with a gentle fade-in.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(onboardingDoneProvider, (previous, next) {
      next.whenData((done) {
        if (context.mounted) {
          context.go(done ? '/home' : MusePaths.onboarding);
        }
      });
    });

    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? MuseColors.darkSurface : MuseColors.baseSurface,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          builder: (context, value, child) =>
              Opacity(opacity: value, child: child),
          child: Image.asset(
            'lib/assets/appicon.png',
            width: 220,
            height: 220,
          ),
        ),
      ),
    );
  }
}