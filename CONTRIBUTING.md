# Contributing to Muse

Thanks for helping! This project keeps things simple: issues and PRs on
GitHub, no formal process beyond the below.

## Reporting bugs

Open a [GitHub issue](https://github.com/Darkstrike03/muse/issues) with:

- Platform (Windows/Android) and app version (Settings → version row)
- What you did, what you expected, what happened
- Relevant logs if you have them (`flutter run` console output; on Android
  also `adb logcat -s flutter TorService tor`)

## Pull requests

1. Fork, create a feature branch from `main`.
2. Keep changes focused — one topic per PR.
3. Run locally before pushing:
   ```sh
   flutter analyze   # must be clean
   flutter test      # must pass
   ```
4. New features need tests where practical. The existing suite covers
   networking (SOCKS/share server), storage, playback races, and widget
   flows with fakes instead of real engines — follow those patterns
   (`test/support/fakes.dart`).
5. Write commit messages in the imperative mood ("Add X", "Fix Y").

## Design notes

- No telemetry, ever. Network calls are peer-to-peer over Tor or explicit,
  user-triggered metadata checks (update check).
- Don't add dependencies casually; every one ships inside both platform
  builds.
- UI follows the existing gold/marble design language — no new color or
  spacing values outside `core/theme`.

## Licensing

By contributing, you agree your contributions are licensed under the
Apache License 2.0, the project's license.
