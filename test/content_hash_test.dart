// test/content_hash_test.dart
//
// Pure-Dart sanity check for the audit-log fingerprint helper (no plugins, so
// it runs under headless `flutter test`). The crypto/keys paths that need the
// Keystore/platform delegate are exercised on-device by the consuming app.

import 'package:flutter_test/flutter_test.dart';
import 'package:sumaflow_digest_privacy_core/sumaflow_digest_privacy_core.dart';

void main() {
  test('ContentHash.ofString is stable, lowercase-hex SHA-256', () {
    // Known SHA-256 of the empty string.
    expect(
      ContentHash.ofString(''),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    // Deterministic + 64 hex chars.
    final h = ContentHash.ofString('exported-payload');
    expect(h, ContentHash.ofString('exported-payload'));
    expect(h, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('ContentHash.ofBytes matches ofString for the same content', () {
    expect(ContentHash.ofBytes('abc'.codeUnits), ContentHash.ofString('abc'));
  });
}
