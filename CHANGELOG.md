# Changelog

All notable changes to Muse are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and releases are
tagged `vX.Y.Z` in git; tags drive the GitHub Releases that the in-app
update checker reads.

## [Unreleased]

### Added
- P2P music streaming between paired devices over Tor onion services.
- Friend sync: shared playlists/albums/folders from reachable friends import
  automatically as Library playlists ("Shared · N songs") and refresh on a
  30s poll or manual refresh.
- Real Tor on Android via the Guardian `tor-android` foreground service.
- Playback race hardening: rapid track taps always play the last selection;
  a mid-song stream death now pauses instead of silently skipping.
- Storage permission request when adding a music folder on Android;
  unreadable folders no longer break the whole library scan.
- Manual update check against GitHub Releases (Settings).
- CI (analyze + tests) and tag-driven release workflow producing signed
  split-per-ABI APKs, a portable Windows ZIP, an Inno Setup installer, and
  SHA256 checksums.

[Unreleased]: https://github.com/Darkstrike03/muse/compare/v0.9.0...HEAD
