// lib/src/storage/secure_storage.dart
//
// Single source of truth for the flutter_secure_storage Android backend.
// EVERY FlutterSecureStorage instance in the consuming app MUST use these
// options so that all keys live in the same Keystore-backed
// EncryptedSharedPreferences bucket and behave identically across OEM quirks
// (TECHSPEC §10).
//
// Why centralised: a bare `const FlutterSecureStorage()` defaults to
// `encryptedSharedPreferences: false` — the legacy keystore-wrapped backend —
// which on some OEMs fails to decrypt its values back after an app restart.
// Mixing that with `encryptedSharedPreferences: true` elsewhere silently
// reverts reads to null. Centralising the options removes that divergence.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AndroidOptions shared by every secure-storage instance in the app.
/// `const` so it slots straight into `const FlutterSecureStorage(...)`.
const AndroidOptions kAppAndroidSecureStorageOptions = AndroidOptions(
  encryptedSharedPreferences: true,
  // StrongBox where available per TECHSPEC §10.
  keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
  storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
);

/// The app-wide secure storage instance. Const-constructible so headless
/// isolates (which have no Riverpod scope) can build the identical store.
const FlutterSecureStorage appSecureStorage = FlutterSecureStorage(
  aOptions: kAppAndroidSecureStorageOptions,
);
