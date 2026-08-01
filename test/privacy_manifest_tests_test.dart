// test/privacy_manifest_tests_test.dart
//
// Tests the privacy assertions themselves. An audit artifact whose checks are
// unverified is decoration: each rule is exercised in BOTH directions — a
// compliant manifest produces no violation, and a manifest that breaks the rule
// produces exactly that violation. Pure string input, so it runs headless.

import 'package:flutter_test/flutter_test.dart';
import 'package:sumaflow_digest_privacy_core/testing.dart';

/// A manifest matching the shipped Digest posture: on-device permissions only,
/// INTERNET declared *with* its model-download rationale, cleartext and adb
/// backup both off.
const _compliantManifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <!-- The single allowed outbound path: the optional, Wi-Fi gated AI model
         download from huggingface.co (model download only). -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <application
        android:label="SumaFlow Digest"
        android:allowBackup="false"
        android:usesCleartextTraffic="false">
    </application>
</manifest>
''';

void main() {
  group('privacyManifestViolations', () {
    test('the shipped Digest posture is clean', () {
      expect(
        privacyManifestViolations(
          _compliantManifest,
          forbiddenPermissions: [
            'RECORD_AUDIO',
            ...kDefaultForbiddenPermissions,
          ],
          requiredPermissions: ['android.permission.CAMERA'],
        ),
        isEmpty,
      );
    });

    test('flags a forbidden permission', () {
      final manifest = _compliantManifest.replaceFirst(
        '</application>',
        '</application>\n'
            '<uses-permission android:name="android.permission.RECORD_AUDIO"/>',
      );
      expect(
        privacyManifestViolations(
          manifest,
          forbiddenPermissions: [
            'RECORD_AUDIO',
            ...kDefaultForbiddenPermissions,
          ],
        ),
        contains(contains('RECORD_AUDIO')),
      );
    });

    test('flags a required permission that went missing', () {
      expect(
        privacyManifestViolations(
          _compliantManifest,
          requiredPermissions: ['android.permission.NEVER_DECLARED'],
        ),
        contains(contains('NEVER_DECLARED')),
      );
    });

    test('flags INTERNET declared without a documented rationale', () {
      // Strip the rationale comment, keep the permission.
      final manifest = _compliantManifest.replaceFirst(
        RegExp(r'<!--.*?-->', dotAll: true),
        '',
      );
      expect(
        privacyManifestViolations(manifest),
        contains(contains('rationale is not documented')),
      );
    });

    test('accepts INTERNET when the rationale is documented', () {
      expect(
        privacyManifestViolations(_compliantManifest),
        isNot(contains(contains('rationale'))),
      );
    });

    test('says nothing about INTERNET when it is not declared at all', () {
      final manifest = _compliantManifest
          .replaceFirst(
            '<uses-permission android:name="android.permission.INTERNET"/>',
            '',
          )
          .replaceFirst(RegExp(r'<!--.*?-->', dotAll: true), '');
      expect(privacyManifestViolations(manifest), isEmpty);
    });

    test('flags cleartext traffic left enabled', () {
      final manifest = _compliantManifest.replaceFirst(
        'android:usesCleartextTraffic="false"',
        'android:usesCleartextTraffic="true"',
      );
      expect(
        privacyManifestViolations(manifest),
        contains(contains('Cleartext traffic must be disabled')),
      );
    });

    test('flags adb backup left enabled', () {
      final manifest = _compliantManifest.replaceFirst(
        'android:allowBackup="false"',
        'android:allowBackup="true"',
      );
      expect(
        privacyManifestViolations(manifest),
        contains(contains('adb backup must be off')),
      );
    });

    test('flags an omitted allowBackup attribute, not just an enabled one', () {
      // Android defaults allowBackup to true, so silence is a violation.
      final manifest = _compliantManifest.replaceFirst(
        '        android:allowBackup="false"\n',
        '',
      );
      expect(
        privacyManifestViolations(manifest),
        contains(contains('adb backup must be off')),
      );
    });

    test('the transport rules can be waived explicitly', () {
      final manifest = _compliantManifest
          .replaceFirst('android:allowBackup="false"', '')
          .replaceFirst('android:usesCleartextTraffic="false"', '');
      expect(
        privacyManifestViolations(
          manifest,
          requireBackupDisabled: false,
          requireCleartextDisabled: false,
        ),
        isEmpty,
      );
    });
  });

  group('privacyTelemetryViolations', () {
    test('a clean pubspec produces no violations', () {
      expect(
        privacyTelemetryViolations('dependencies:\n  crypto: ^3.0.6\n'),
        isEmpty,
      );
    });

    test('flags a known-telemetry package', () {
      expect(
        privacyTelemetryViolations(
          'dependencies:\n  firebase_analytics: ^11.0.0\n',
        ),
        contains(contains('firebase_analytics')),
      );
    });

    test('flags every offender, not just the first', () {
      expect(
        privacyTelemetryViolations(
          'dependencies:\n'
          '  sentry_flutter: ^8.0.0\n'
          '  posthog_flutter: ^4.0.0\n',
        ),
        hasLength(2),
      );
    });
  });
}
