// lib/sumaflow_digest_privacy_core.dart
//
// Runtime entry point for SumaFlow Digest — Privacy Core.
//
// This barrel exports the privacy-critical *runtime* modules consumed by the
// main Digest app. Test-only helpers (the manifest regression test and the
// network-asserting HttpOverrides) live behind the separate `testing.dart`
// entry point so production builds never pull in flutter_test.
//
// Modules:
//   crypto/   — AES-256-GCM at-rest file encryption + SHA-256 content hashing
//   keys/     — single-master-key generation + HKDF subkey derivation
//   storage/  — the shared flutter_secure_storage (Keystore) backend config
//
// Separate from sumaflow-minutes-privacy-core by design (separation of duties):
// each app owns and audits its own privacy core. No audio/recording surface
// lives here.

export 'src/crypto/aead_file.dart';
export 'src/crypto/content_hash.dart';
export 'src/keys/master_key.dart';
export 'src/storage/secure_storage.dart';
