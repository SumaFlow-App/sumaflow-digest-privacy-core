// lib/src/crypto/content_hash.dart
//
// TECHSPEC §9 — every export audit-log row stores SHA-256(exported_payload).
// This is the *exported* payload (after redaction/render, just before the
// export intent fires), never the source content — the log records *that* you
// exported plus a fingerprint, not what you exported.

import 'dart:convert';

import 'package:crypto/crypto.dart';

class ContentHash {
  /// SHA-256 of a UTF-8 string, returned as lowercase hex.
  static String ofString(String s) => sha256.convert(utf8.encode(s)).toString();

  /// SHA-256 of arbitrary bytes (e.g. an exported PDF buffer), lowercase hex.
  static String ofBytes(List<int> bytes) => sha256.convert(bytes).toString();
}
