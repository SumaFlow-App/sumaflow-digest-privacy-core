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
// NETWORK POSTURE — the honest contract, stated precisely:
//   * ZERO outbound calls ever carry user content. No document, page image,
//     OCR text, summary, extraction or redaction leaves the device, ever.
//   * The one outbound flow the app itself initiates is the opt-in, Wi-Fi-only,
//     SHA256-verified model download from huggingface.co. It is a download —
//     bytes come in, nothing goes out but the request.
//   * Billing, if the app ships a paid tier, talks to Google Play through the
//     platform's own billing client. It carries purchase tokens, never content,
//     and it is not the app opening a socket.
// These assertions therefore do NOT forbid INTERNET outright; they enforce that,
// if declared, it carries a documented rationale, and that nothing else
// network/sensor-adjacent ever appears. What INTERNET is actually *used* for is
// pinned separately by the source scan — see privacy_source_scan_tests.dart.
//
// The assertion logic lives in pure `*Violations` functions so it is directly
// unit-testable (this package tests each in both directions); the `test()`
// registrations are thin wrappers.

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

/// Returns a violation string for every manifest rule [manifest] breaks.
/// Empty means clean. Pure over the manifest's text so it can be unit-tested
/// against both a compliant and a violating fixture.
List<String> privacyManifestViolations(
  String manifest, {
  List<String> forbiddenPermissions = kDefaultForbiddenPermissions,
  List<String> requiredPermissions = const <String>[],
  List<String> internetRationaleMarkers = kDefaultInternetRationaleMarkers,
  bool requireCleartextDisabled = true,
  bool requireBackupDisabled = true,
}) {
  final violations = <String>[];

  for (final permission in requiredPermissions) {
    if (!manifest.contains(permission)) {
      violations.add('$permission is required for the core flow but absent.');
    }
  }

  for (final permission in forbiddenPermissions) {
    if (manifest.contains('android.permission.$permission')) {
      violations.add(
        'PRIVACY VIOLATION: $permission is declared. This app does not require '
        'it. If you are adding it, update the privacy policy and architecture '
        'page FIRST.',
      );
    }
  }

  if (manifest.contains('android.permission.INTERNET') &&
      !internetRationaleMarkers.any(manifest.contains)) {
    violations.add(
      'INTERNET is declared but its rationale is not documented. Add a comment '
      'explaining the on-device-inference / opt-in-download split (and disclose '
      'it in the privacy whitepaper).',
    );
  }

  if (requireCleartextDisabled &&
      !manifest.contains('android:usesCleartextTraffic="false"')) {
    violations.add(
      'Cleartext traffic must be disabled — android:usesCleartextTraffic='
      '"false" (TECHSPEC §10).',
    );
  }

  // adb backup would hand an attacker with USB access the encrypted store and
  // every Keystore-wrapped artifact sitting next to it. Off is the only setting
  // consistent with "even we cannot recover it".
  if (requireBackupDisabled &&
      !manifest.contains('android:allowBackup="false"')) {
    violations.add(
      'adb backup must be off — android:allowBackup="false" — so the encrypted '
      'store cannot be pulled off the device (TECHSPEC §10).',
    );
  }

  return violations;
}

/// Returns a violation string for every known-telemetry package named in
/// [pubspec]. Empty means clean.
List<String> privacyTelemetryViolations(
  String pubspec, {
  List<String> telemetryPackages = kDefaultTelemetryPackages,
}) {
  final violations = <String>[];
  for (final package in telemetryPackages) {
    if (pubspec.contains(package)) {
      violations.add(
        'PRIVACY VIOLATION: $package is a known-telemetry package. No '
        'third-party SDK that phones home.',
      );
    }
  }
  return violations;
}

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
  bool requireBackupDisabled = true,
}) {
  group('PRIVACY: Android manifest', () {
    test('Manifest honours the permission + transport contract', () {
      final violations = privacyManifestViolations(
        File(manifestPath).readAsStringSync(),
        forbiddenPermissions: forbiddenPermissions,
        requiredPermissions: requiredPermissions,
        internetRationaleMarkers: internetRationaleMarkers,
        requireCleartextDisabled: requireCleartextDisabled,
        requireBackupDisabled: requireBackupDisabled,
      );
      expect(
        violations,
        isEmpty,
        reason: 'In $manifestPath:\n${violations.join('\n')}',
      );
    });
  });

  group('PRIVACY: pubspec dependencies', () {
    test('No known-telemetry packages in dependencies', () {
      final violations = privacyTelemetryViolations(
        File(pubspecPath).readAsStringSync(),
        telemetryPackages: telemetryPackages,
      );
      expect(
        violations,
        isEmpty,
        reason: 'In $pubspecPath:\n${violations.join('\n')}',
      );
    });
  });
}
