import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Locates the bundled Tor daemon binary for the current platform.
///
/// Candidates, in order:
///   1. `MUSE_TOR_DIR` environment variable (e.g. for development).
///   2. `<app support>/tor/tor.exe` — where `tool/setup_tor.ps1` installs it.
///   3. `<working dir>/tor/<platform>/` — a repo checkout used for dev builds.
///   4. `<executable dir>/tor/` — for packaged builds.
Future<String?> findTorBinary() async {
  final name = _binaryName();

  final envDir = Platform.environment['MUSE_TOR_DIR'];
  if (envDir != null && envDir.isNotEmpty) {
    final candidate = File('$envDir${Platform.pathSeparator}$name');
    if (await candidate.exists()) return candidate.path;
  }

  final support = await getApplicationSupportDirectory();
  for (final base in [support.path, Directory.current.path]) {
    for (final sub in ['tor/windows', 'tor']) {
      final candidate = File(
          '$base${Platform.pathSeparator}$sub${Platform.pathSeparator}$name');
      if (await candidate.exists()) return candidate.path;
    }
  }

  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final exeCandidate = File('$exeDir${Platform.pathSeparator}tor${Platform.pathSeparator}$name');
  if (await exeCandidate.exists()) return exeCandidate.path;

  return null;
}

String _binaryName() {
  if (Platform.isWindows) return 'tor.exe';
  if (Platform.isAndroid) return 'tor';
  if (Platform.isLinux) return 'tor';
  if (Platform.isMacOS) return 'tor';
  return 'tor';
}