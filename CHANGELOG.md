# Changelog

## 0.2.0

Catches the audit artifact up with what the Digest app actually enforces. The
app had grown a hand-rolled privacy gate that was *stricter* than the published
core — which is the wrong way round for a repo whose purpose is letting outsiders
verify the contract. Everything the app checks now lives here.

### Added

- `privacySourceScanTests` / `privacySourceScanViolations`
  (`testing.dart`) — scans the app's own Dart source for networking APIs
  (`package:http/`, `HttpClient(`, sockets, …) and for any `http(s)://` literal
  whose host is not explicitly allowlisted. This is the check that keeps the
  no-cloud claim falsifiable now that INTERNET is legitimately declared for the
  model download: a permission-only audit can no longer tell you whether a new
  endpoint slipped in. A missing source root is reported as a violation rather
  than passing silently.
- `requireBackupDisabled` (default `true`) in `privacyManifestTests` — asserts
  `android:allowBackup="false"`, so the encrypted store and its Keystore-wrapped
  keys cannot be pulled off the device over adb. Android defaults this to `true`,
  so an *omitted* attribute is a violation, not just an enabled one.
- Pure violation functions — `privacyManifestViolations`,
  `privacyTelemetryViolations`, `privacySourceScanViolations` — returning a list
  of human-readable violations. The `test()` wrappers are now thin shells over
  them, which is what makes the rules unit-testable.
- Tests for the assertions themselves: every rule is exercised in both
  directions (compliant fixture passes; fixture breaking that one rule fails).
  25 tests, up from 2.
- CI (`.github/workflows/ci.yml`) — format, analyze, test, on the same pinned
  Flutter version as the consuming app. The repo previously had none, so its own
  test suite never ran automatically.

### Changed

- Network-posture documentation now states the contract precisely instead of
  "one exception": zero outbound calls carry user *content*; the model download
  is the one app-initiated flow; Play Billing carries purchase tokens through
  the platform billing client. The README maps each claim to the check that
  enforces it.
- `PrivacyAssertingHttpOverrides` documents what it structurally cannot see —
  native-layer traffic and platform billing — so a green run is not read as
  covering more than it does.
- The two Android-manifest test cases were merged into one that reports every
  violation at once, rather than failing on whichever rule tripped first.

### Upgrading from 0.1.0

`requireBackupDisabled` defaults to `true`, so a consumer without
`android:allowBackup="false"` will newly fail. That is the intended behaviour;
pass `requireBackupDisabled: false` only with a documented reason.

## 0.1.0

Initial extraction: master key + HKDF subkeys, AES-256-GCM file encryption,
content hashing, the shared Keystore secure-storage config, and the first
manifest/pubspec regression tests.
