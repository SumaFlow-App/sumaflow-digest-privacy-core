# sumaflow_digest_privacy_core

Privacy-critical modules of **SumaFlow Digest** — open-sourced under MIT so the
on-device, no-cloud privacy contract (PRD §13, TECHSPEC §10) is **independently
verifiable**. The main Digest app is closed-source; this core is not, so anyone
can audit exactly how keys are managed, how data is encrypted at rest, and that
nothing phones home.

## Why a separate repo (separation of duties)

Digest is a sibling of SumaFlow Minutes and shares the *same shape* of privacy
core, but it does **not** depend on Minutes' core. Each app owns and audits its
own privacy core so the two products stay decoupled — different release cadences,
different threat surfaces (Digest has no microphone/recording path at all), and
a clean, self-contained audit artifact per app. This repo mirrors the Minutes
core's structure; it does not reference it.

## Modules

| Path | What |
|---|---|
| `keys/master_key.dart` | Single per-install master key in Android Keystore; HKDF-SHA256 subkeys (`sqlcipher-v1`, `file-aead-v1`). |
| `crypto/aead_file.dart` | AES-256-GCM at-rest file encryption (`[nonce][mac][ciphertext]`). |
| `crypto/content_hash.dart` | SHA-256 for export audit-log fingerprints. |
| `storage/secure_storage.dart` | The one shared Keystore-backed `flutter_secure_storage` config. |
| `testing.dart` → `privacy_manifest_tests.dart` | App-agnostic manifest/pubspec regression tests (forbidden permissions, INTERNET rationale, cleartext off, adb backup off, no telemetry). |
| `testing.dart` → `privacy_source_scan_tests.dart` | Scans the app's own Dart source for networking APIs and any non-allowlisted host. |
| `testing.dart` → `privacy_asserting_http_overrides.dart` | `HttpOverrides` that fails any test the moment an `HttpClient` is created. |

## The network posture, stated precisely

The claim is not "the app has no INTERNET permission" — it does, and pretending
otherwise would be the dishonest version. The claim is narrower and stronger:

* **Zero outbound calls ever carry user content.** No document, page image, OCR
  text, summary, extraction or redaction leaves the device, ever.
* The one outbound flow the app initiates is the **opt-in, Wi-Fi-only,
  SHA256-verified model download** from `huggingface.co`. Bytes come in; nothing
  but the request goes out. It runs in the native layer behind a platform
  channel.
* **Google Play Billing**, for the paid tier, reaches Play through the platform's
  billing client. It carries purchase tokens, never content.

Each clause maps to a check you can run:

| Claim | Enforced by |
|---|---|
| No endpoint but the model host appears in app source | `privacySourceScanTests` — host allowlist + a ban on `package:http/`, `HttpClient(`, sockets |
| INTERNET is declared *and disclosed* | `privacyManifestTests` — the rationale must be documented in the manifest itself |
| Nothing sensor- or network-adjacent creeps in | `privacyManifestTests` — forbidden-permission list |
| The encrypted store can't be pulled off the device | `privacyManifestTests` — `allowBackup="false"`, `usesCleartextTraffic="false"` |
| No third-party SDK phones home | `privacyManifestTests` — known-telemetry denylist |
| Flows that must be silent stay silent | `PrivacyAssertingHttpOverrides` |

The assertion logic is factored into pure functions
(`privacyManifestViolations`, `privacyTelemetryViolations`,
`privacySourceScanViolations`) that return a list of violations, and this repo's
own tests exercise every rule **in both directions** — a compliant fixture must
pass, and a fixture breaking that one rule must fail. A check nobody has watched
fail is not a check.

## Usage

Consumed by the main app via a **pinned git ref** (not a path dependency), so CI
and fresh clones resolve with no sibling checkout:

```yaml
dependencies:
  sumaflow_digest_privacy_core:
    git:
      url: https://github.com/SumaFlow-App/sumaflow-digest-privacy-core.git
      ref: <commit-sha>
```

```dart
import 'package:sumaflow_digest_privacy_core/sumaflow_digest_privacy_core.dart';
// ... ref.watch(masterKeyManagerProvider).deriveSubkey(purpose: 'sqlcipher-v1');
```

Registering the privacy gate in the consuming app's `test/` directory — this is
the whole of Digest's `test/privacy_manifest_test.dart`:

```dart
import 'package:sumaflow_digest_privacy_core/testing.dart';

void main() {
  privacySourceScanTests(allowedHosts: const {'huggingface.co'});
  privacyManifestTests(
    manifestPath: 'android/app/src/main/AndroidManifest.xml',
    pubspecPath: 'pubspec.yaml',
    // Digest is a document app: no recording path exists, and none may appear.
    forbiddenPermissions: const ['RECORD_AUDIO', ...kDefaultForbiddenPermissions],
    requiredPermissions: const ['android.permission.CAMERA'],
  );
}
```

## License

MIT — see [LICENSE](LICENSE). Fonts/icons/app content are not part of this package.
