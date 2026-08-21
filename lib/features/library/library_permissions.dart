import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Seam around the platform permission plugin so the folder-add flows stay
/// testable (the plugin is a platform channel and can't run in tests).
final musicPermissionProvider = Provider<Future<bool> Function()>(
  (ref) => ensureMusicFolderAccess,
);

/// Ensures the app may read audio files from shared storage before a picked
/// music folder is scanned. Desktop needs nothing; Android needs
/// READ_EXTERNAL_STORAGE (API ≤32) or READ_MEDIA_AUDIO (API 33+), with
/// All-Files-Access as the last resort. Returns whether access was granted.
Future<bool> ensureMusicFolderAccess() async {
  if (!Platform.isAndroid) return true;

  // On API ≤32 this shows the runtime dialog; on 33+ it resolves immediately
  // (the manifest caps READ_EXTERNAL_STORAGE at 32).
  var status = await Permission.storage.request();
  if (status.isGranted) return true;

  status = await Permission.audio.request();
  if (status.isGranted) return true;

  // All-Files-Access (API 30+): opens the system settings page and completes
  // when the user returns. On older versions it resolves without granting.
  status = await Permission.manageExternalStorage.request();
  return status.isGranted;
}
