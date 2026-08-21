# Muse

Listen together, apart. Muse is a local-first music player for **Windows**
and **Android** that lets you share your library with friends — directly,
device to device, through the Tor anonymity network. No accounts, no cloud,
no servers: your music never leaves your devices except as an encrypted
circuit between you and the people you paired with.

## How it works

- **Pairing** — exchange a QR/pairing code once; each device learns the
  other's onion address (a 56-character v3 hidden-service name).
- **Sharing** — pick what to share: everything, specific playlists, albums,
  or folders.
- **Streaming** — friends browse your shared scopes and stream songs on
  demand over Tor onion services. Played tracks can be cached locally for
  offline replay.
- **Friend sync** — whatever a friend shares appears in your Library as
  read-only playlists (`Shared · N songs`) and stays up to date
  automatically while you're both online.

Nothing is uploaded anywhere. Every connection is peer-to-peer over Tor;
there is no central service and no telemetry.

## Install

Grab signed builds from the
[Releases page](https://github.com/Darkstrike03/muse/releases). Every
release ships SHA256 checksums — verify before installing.

| Platform | Artifact | Notes |
|---|---|---|
| Windows | `muse-setup-<ver>.exe` | Inno Setup installer |
| Windows | `muse-<ver>-portable.zip` | Portable ZIP, no install needed |
| Android | `muse-<ver>-arm64-v8a.apk` | Modern phones (2016+) |
| Android | `muse-<ver>-armeabi-v7a.apk` | Older 32-bit phones |
| Android | `muse-<ver>-x86_64.apk` | Emulators |

Windows note: the installer/ZIP is not code-signed yet, so SmartScreen may
show a warning — choose *More info → Run anyway*. The first launch downloads
the official Tor binaries via `tool/setup_tor.ps1` (already included in
release artifacts).

Android notes: Muse requests audio-read permission when you add a music
folder. On first start it runs Tor in a foreground service (you'll see its
notification) and may take ~30 seconds to bootstrap.

## Building from source

Requirements: Flutter (stable channel), JDK 17 for Android, Visual Studio
Build Tools "Desktop development with C++" for Windows.

```sh
git clone https://github.com/Darkstrike03/muse.git
cd muse
flutter pub get

# Windows desktop (downloads Tor binaries into tor/)
./tool/setup_tor.ps1
flutter run -d windows

# Android device or emulator (Tor ships inside the app)
flutter run -d android
```

Tests:

```sh
flutter analyze
flutter test
```

Release signing material is intentionally not in the repo — see
`.github/workflows/release.yml` for how CI injects it.

## Security model & disclaimer

- Traffic between devices rides inside Tor onion circuits; neither your IP
  nor your friend's is exposed to the other or to observers.
- The update check (Settings → Check for updates) is manual only and talks
  directly to api.github.com; it sends nothing but a standard HTTP request.
- Shared tracks are served by your own device from your own disk — only
  scopes you explicitly share are reachable, everything else returns 403.
- This software is provided AS IS under the Apache License 2.0. Streaming
  music you don't have rights to share may be illegal where you live;
  respect copyright and the people who make the music.

## Contributing

Bug reports and pull requests are welcome — see
[CONTRIBUTING.md](CONTRIBUTING.md). Security issues: please follow
[SECURITY.md](SECURITY.md) rather than opening a public issue.

## License

Copyright 2026 Darkstrike03.

Licensed under the [Apache License, Version 2.0](LICENSE); see
[NOTICE](NOTICE) and [THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md) for
the third-party components bundled with Muse (Tor, libmpv/media_kit,
Flutter, and others).
