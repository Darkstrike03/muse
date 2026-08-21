import 'package:flutter_test/flutter_test.dart';

import 'package:muse/features/settings/update_checker.dart';

void main() {
  group('compareVersions', () {
    test('major/minor/patch ordering', () {
      expect(compareVersions('1.1.0', '1.0.9'), greaterThan(0));
      expect(compareVersions('1.2.10', '1.2.9'), greaterThan(0));
      expect(compareVersions('2.0.0', '1.99.99'), greaterThan(0));
      expect(compareVersions('1.0.0', '1.0.0'), 0);
      expect(compareVersions('1.0.0', '2.0.0'), lessThan(0));
    });

    test('missing segments count as zero', () {
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1.3', '1.2.9'), greaterThan(0));
      expect(compareVersions('1', '1.0.1'), lessThan(0));
    });
  });

  group('parseRelease', () {
    const currentVersion = '1.2.3';

    test('newer release (v-prefixed tag) reports an update', () {
      final result = parseRelease(
        '{"tag_name":"v1.3.0","html_url":"https://github.com/Darkstrike03/muse/releases/tag/v1.3.0"}',
        currentVersion,
      );
      expect(result.hasUpdate, isTrue);
      expect(result.newVersion, '1.3.0');
      expect(
        result.releaseUrl,
        'https://github.com/Darkstrike03/muse/releases/tag/v1.3.0',
      );
    });

    test('older or equal releases report up to date', () {
      for (final tag in ['v1.2.3', '1.2.2', 'v1.0.0']) {
        final result = parseRelease('{"tag_name":"$tag"}', currentVersion);
        expect(result.hasUpdate, isFalse, reason: tag);
        expect(result.newVersion, isNull);
        expect(result.currentVersion, currentVersion);
      }
    });

    test('missing tag is an error', () {
      expect(() => parseRelease('{"foo":1}', currentVersion),
          throwsA(isA<FormatException>()));
      expect(() => parseRelease('[1]', currentVersion),
          throwsA(isA<FormatException>()));
    });

    test('falls back to the releases page when html_url is absent', () {
      final result = parseRelease('{"tag_name":"v9.0.0"}', currentVersion);
      expect(result.releaseUrl, releasesPageUrl);
    });
  });
}