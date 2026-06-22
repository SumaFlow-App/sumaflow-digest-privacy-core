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
| `testing.dart` → `privacy_manifest_tests.dart` | App-agnostic manifest/pubspec regression tests (forbidden permissions, cleartext off, no telemetry). |
| `testing.dart` → `privacy_asserting_http_overrides.dart` | `HttpOverrides` that fails any test the moment an `HttpClient` is created. |

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

## License

MIT — see [LICENSE](LICENSE). Fonts/icons/app content are not part of this package.
