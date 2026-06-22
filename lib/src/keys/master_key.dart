// lib/src/keys/master_key.dart
//
// TECHSPEC §10 — single master key per install, generated on first launch,
// stored in Android Keystore via flutter_secure_storage. All other keys (the
// SQLCipher DB key, at-rest file encryption) are derived from this master via
// HKDF to keep concerns separated.

import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../storage/secure_storage.dart';

final masterKeyManagerProvider = Provider<MasterKeyManager>(
  (ref) => MasterKeyManager(appSecureStorage),
);

class MasterKeyManager {
  MasterKeyManager(this._storage);
  final FlutterSecureStorage _storage;

  /// Secure-storage key under which the persisted master key lives. Namespaced
  /// to Digest so it never collides with a sibling app's key (separation of
  /// duties). Exposed for tests that pre-seed a deterministic key.
  @visibleForTesting
  static const masterKeyStorageKey = 'sumaflow_digest_master_key_v1';

  /// Returns the 32-byte master key, generating it on first call.
  /// The key never leaves the device's Keystore-backed storage.
  Future<SecretKey> getOrCreate() async {
    final existing = await _storage.read(key: masterKeyStorageKey);
    if (existing != null) {
      return SecretKey(base64Decode(existing));
    }
    // `AesGcm.with256bits().newSecretKey()` draws 256 bits from the platform
    // CSPRNG — never `dart:math` Random, which is not secure.
    final key = await AesGcm.with256bits().newSecretKey();
    final keyBytes = await key.extractBytes();
    await _storage.write(
      key: masterKeyStorageKey,
      value: base64Encode(keyBytes),
    );
    return key;
  }

  /// Overwrites the persisted master key with [keyBytes] (32 bytes). Used by a
  /// backup/restore apply-step that must run before the DB is opened or any
  /// subkey is derived, so the restored data decrypts under the backup's key.
  /// Idempotent: re-running with the same bytes is a no-op write.
  Future<void> restoreMasterKey(List<int> keyBytes) async {
    await _storage.write(
      key: masterKeyStorageKey,
      value: base64Encode(keyBytes),
    );
  }

  /// Derives a purpose-specific subkey via HKDF-SHA256.
  /// Use 'sqlcipher-v1' for the DB key, 'file-aead-v1' for file encryption.
  Future<SecretKey> deriveSubkey({required String purpose}) async {
    final master = await getOrCreate();
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: master,
      info: utf8.encode(purpose),
      // RFC 5869 §2.2 — when no salt is provided, HKDF uses "a string of
      // HashLen zeros". Encoding that fallback explicitly keeps the derivation
      // identical whether HMAC runs in pure Dart (host tests) or on the
      // platform delegate (cryptography_flutter on Android, which rejects a
      // zero-length salt array via SecretKeySpec).
      nonce: List<int>.filled(32, 0),
    );
  }
}
