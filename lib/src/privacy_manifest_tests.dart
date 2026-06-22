// lib/src/privacy_manifest_tests.dart
//
// PRIVACY MANIFEST REGRESSION TEST — TECHSPEC §10.
//
// App-agnostic: every list is a parameter with a sensible default, so any
// SumaFlow app can register the same assertions against its own manifest +
// pubspec. (This is the deliberate generalization of the Minutes core's
// audio-specific version — Digest is a document app and must NOT, for example,
// require RECORD_AUDIO.)
//
// NETWORK POSTURE — the honest contract: the app performs ZERO outbound calls
// carrying content during normal operation. The ONE exception is an opt-in,
// Wi-Fi-only, SHA256-verified model download from huggingface.co. These
// assertions therefore do NOT forbid INTERNET outright; they enforce that, if
// declared, it carries a documented rationale, and that nothing else
// network/sensor-adjacent ever appears.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Substrings that prove the INTERNET permission's rationale is documented in
/// the manifest (the model-download split). Override per app.
const List<String> kDefaultInternetRationaleMarkers = <String>[
  'huggingface.co',
  'model download',
];

/// Permissions a privacy-first SumaFlow app should never declare. Apps add to
/// this (e.g. a document app forbids RECORD_AUDIO; an audio app would not).
const List<String> kDefaultForbiddenPermissions = <String>[
  'READ_CONTACTS',
  'WRITE_CONTACTS',
  'READ_CALENDAR',
  'WRITE_CALENDAR',
  'ACCESS_FINE_LOCATION',
  'ACCESS_COARSE_LOCATION',
  'ACCESS_BACKGROUND_LOCATION',
  'READ_PHONE_STATE',
  'READ_SMS',
  'ACCESS_WIFI_STATE',
  'CHANGE_WIFI_STATE',
  'CHANGE_NETWORK_STATE',
];

const List<String> kDefaultTelemetryPackages = <String>[
  'firebase_analytics',
  'firebase_crashlytics',
  'mixpanel_flutter',
  'amplitude_flutter',
  'sentry_flutter',
  'segment_analytics_flutter',
  'posthog_flutter',
  'google_analytics',
  'facebook_app_events',
];

/// Registers the SumaFlow privacy-manifest regression tests against a specific
/// consumer's Android manifest and pubspec. Call from a `test/` file:
///
/// ```dart
/// import 'package:sumaflow_digest_privacy_core/testing.dart';
///
/// void main() => privacyManifestTests(
///       manifestPath: 'android/app/src/main/AndroidManifest.xml',
///       pubspecPath: 'pubspec.yaml',
///       forbiddenPermissions: ['RECORD_AUDIO', ...kDefaultForbiddenPermissions],
///     );
/// ```
void privacyManifestTests({
  required String manifestPath,
  required String pubspecPath,
  List<String> forbiddenPermissions = kDefaultForbiddenPermissions,
  List<String> requiredPermissions = const <String>[],
  List<String> internetRationaleMarkers = kDefaultInternetRationaleMarkers,
  List<String> telemetryPackages = kDefaultTelemetryPackages,
  bool requireCleartextDisabled = true,
}) {
  group('PRIVACY: Android manifest', () {
    test('Required permissions are declared', () {
      final manifest = File(manifestPath).readAsStringSync();
      for (final permission in requiredPermissions) {
        expect(
          manifest.contains(permission),
          isTrue,
          reason: '$permission is required for the core flow.',
        );
      }
    });

    test('No forbidden network/sensor-adjacent permission is present', () {
      final manifest = File(manifestPath).readAsStringSync();
      for (final permission in forbiddenPermissions) {
        expect(
          manifest.contains('android.permission.$permission'),
          isFalse,
          reason:
              'PRIVACY VIOLATION: $permission appeared in $manifestPath. This '
              'app does not require it. If you are adding it, update the privacy '
              'policy and architecture page FIRST.',
        );
      }
    });

    test('INTERNET permission, if declared, has its rationale documented', () {
      final manifest = File(manifestPath).readAsStringSync();
      if (!manifest.contains('android.permission.INTERNET')) return;
      expect(
        internetRationaleMarkers.any(manifest.contains),
        isTrue,
        reason:
            'INTERNET is declared in $manifestPath but its rationale is not '
            'documented. Add a comment explaining the on-device-inference / '
            'opt-in-download split (and disclose it in the privacy whitepaper).',
      );
    });

    test('Manifest disables cleartext traffic', () {
      if (!requireCleartextDisabled) return;
      final manifest = File(manifestPath).readAsStringSync();
      expect(
        manifest.contains('android:usesCleartextTraffic="false"'),
        isTrue,
        reason: 'Cleartext traffic must be disabled (TECHSPEC §10).',
      );
    });
  });

  group('PRIVACY: pubspec dependencies', () {
    test('No known-telemetry packages in dependencies', () {
      final pubspec = File(pubspecPath).readAsStringSync();
      for (final package in telemetryPackages) {
        expect(
          pubspec.contains(package),
          isFalse,
          reason:
              'PRIVACY VIOLATION: $package is a known-telemetry package found '
              'in $pubspecPath. No third-party SDK that phones home.',
        );
      }
    });
  });
}
