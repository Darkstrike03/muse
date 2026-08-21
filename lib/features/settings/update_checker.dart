import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Seam so the Settings screen stays testable (network + platform channels
/// can't run in tests).
final updateCheckerProvider = Provider<Future<UpdateCheckResult> Function()>(
  (ref) => checkForUpdate,
);

const _apiHost = 'api.github.com';
const _releasesPath = '/repos/Darkstrike03/muse/releases/latest';
const releasesPageUrl = 'https://github.com/Darkstrike03/muse/releases';

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    this.newVersion,
    this.releaseUrl,
    this.error,
  });

  final String currentVersion;

  /// The newer version when one exists; null when up to date.
  final String? newVersion;
  final String? releaseUrl;

  /// Set when the check itself failed (offline, rate limit, …).
  final String? error;

  bool get hasUpdate => newVersion != null;
}

/// Current app version (from the platform's package metadata — pubspec.yaml's
/// `version` on Android/Windows).
Future<String> currentAppVersion() async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
}

/// Manual update check against GitHub Releases. Runs only when the user asks
/// for it from Settings; the request goes directly to api.github.com (not
/// through Tor) since it carries no user data.
Future<UpdateCheckResult> checkForUpdate() async {
  final current = await currentAppVersion();
  try {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.https(_apiHost, _releasesPath));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final body = await response.transform(utf8.decoder).join();
      return parseRelease(body, current);
    } finally {
      client.close(force: true);
    }
  } catch (e) {
    return UpdateCheckResult(
      currentVersion: current,
      error: e is HttpException ? 'GitHub unreachable (${e.message})' : '$e',
    );
  }
}

UpdateCheckResult parseRelease(String body, String currentVersion) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Unexpected release payload');
  }
  final tag = decoded['tag_name'] as String?;
  if (tag == null || tag.isEmpty) {
    throw const FormatException('Release has no tag');
  }
  final latest = tag.startsWith('v') ? tag.substring(1) : tag;
  if (compareVersions(latest, currentVersion) <= 0) {
    return UpdateCheckResult(currentVersion: currentVersion);
  }
  return UpdateCheckResult(
    currentVersion: currentVersion,
    newVersion: latest,
    releaseUrl:
        decoded['html_url'] as String? ?? releasesPageUrl,
  );
}

/// Compares dotted numeric versions ('1.2.10' vs '1.2.9'); missing segments
/// count as 0 and non-numeric segments compare lexically as fallback.
int compareVersions(String a, String b) {
  final partsA = a.split('.');
  final partsB = b.split('.');
  final length = partsA.length > partsB.length ? partsA.length : partsB.length;
  for (var i = 0; i < length; i++) {
    final segA = i < partsA.length ? partsA[i] : '0';
    final segB = i < partsB.length ? partsB[i] : '0';
    final numA = int.tryParse(segA);
    final numB = int.tryParse(segB);
    if (numA != null && numB != null) {
      if (numA != numB) return numA.compareTo(numB);
    } else {
      final byText = segA.compareTo(segB);
      if (byText != 0) return byText;
    }
  }
  return 0;
}

void openReleasesPage(String url) {
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
