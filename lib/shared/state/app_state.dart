import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user has completed onboarding. Gates the root screen.
final onboardingDoneProvider =
    AsyncNotifierProvider<OnboardingDone, bool>(OnboardingDone.new);

class OnboardingDone extends AsyncNotifier<bool> {
  static const _key = 'onboarding_done';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    state = const AsyncData(true);
  }
}