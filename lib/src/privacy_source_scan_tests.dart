// lib/src/privacy_source_scan_tests.dart
//
// PRIVACY SOURCE SCAN — TECHSPEC §10.
//
// The manifest assertions prove what the app is *allowed* to do; this scan
// proves what the app's Dart source *actually reaches for*. It is the check
// that keeps the no-cloud promise honest now that INTERNET is legitimately
// declared for the opt-in model download: a permission-only audit can no longer
// tell you whether a new endpoint slipped in, but a host allowlist can.
//
// Two assertions over every `.dart` file under the given source roots:
//   1. No networking API token (`package:http/`, `HttpClient(`, sockets, ...).
//   2. Every `http(s)://` literal points at an explicitly allowlisted host.
//
// Both are deliberately crude string/regex checks rather than an AST pass. That
// is a feature for an audit artifact: the rule is legible to a reviewer who
// does not know Dart, and it cannot be defeated by anything short of a
// deliberate obfuscation that would itself be obvious in review.
//
// The logic lives in the pure [privacySourceScanViolations] function so it is
// directly unit-testable (this package tests it in both directions); the
// `test()` registration is a thin wrapper.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Networking entry points that must never appear in a no-cloud app's own
/// source. Anything that opens a socket by any name belongs here.
///
/// Note what this list implies: the ONE legitimate outbound flow (the opt-in,
/// SHA256-verified model download) is expected to live in the *native* layer or
/// behind a platform channel, not in Dart — which is what makes a flat ban on
/// these tokens in `lib/` achievable rather than aspirational.
const List<String> kDefaultForbiddenNetworkTokens = <String>[
  'package:http/',
  'HttpClient(',
  'WebSocket.',
  'RawSocket',
  'Socket.connect',
  'package:dio/',
  'package:web_socket_channel/',
];

/// Hosts that appear in source as *identifiers*, never as endpoints: XML
/// namespace URIs baked into generated OOXML (`.docx`) parts and similar.
/// They are allowlisted so the scan stays meaningful — a scan that everyone
/// has to suppress is a scan nobody reads.
const Set<String> kDefaultXmlNamespaceHosts = <String>{
  'schemas.openxmlformats.org',
  'www.w3.org',
};

/// Matches the host of any `http://` / `https://` literal in source.
final RegExp _urlPattern = RegExp(r'https?://([^/\s"]+)');

/// Returns a human-readable violation for every networking token and
/// non-allowlisted host found under [sourceRoots]. Empty means clean.
///
/// [allowedHosts] is the app's endpoint allowlist — the hosts it may genuinely
/// contact (for Digest: `huggingface.co`, and nothing else). [nonNetworkHosts]
/// are namespace identifiers that are never contacted; they are reported
/// separately in intent but treated the same way — permitted.
///
/// [excludeFile] receives a `/`-normalised path relative to the process working
/// directory and may exempt generated files. Use it sparingly: every exemption
/// is a hole in the audit.
List<String> privacySourceScanViolations({
  List<String> sourceRoots = const <String>['lib'],
  Set<String> allowedHosts = const <String>{},
  Set<String> nonNetworkHosts = kDefaultXmlNamespaceHosts,
  List<String> forbiddenTokens = kDefaultForbiddenNetworkTokens,
  bool Function(String relativePath)? excludeFile,
}) {
  final violations = <String>[];

  for (final root in sourceRoots) {
    final dir = Directory(root);
    if (!dir.existsSync()) {
      violations.add(
        'source root "$root" does not exist — run from the package root, or '
        'fix the sourceRoots argument. A scan that silently inspects nothing '
        'is worse than no scan.',
      );
      continue;
    }

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final rel = entity.path.replaceAll('\\', '/');
      if (excludeFile != null && excludeFile(rel)) continue;

      final source = entity.readAsStringSync();

      for (final token in forbiddenTokens) {
        if (source.contains(token)) {
          violations.add('$rel uses forbidden networking token: $token');
        }
      }

      for (final match in _urlPattern.allMatches(source)) {
        final host = match.group(1)!;
        if (allowedHosts.contains(host) || nonNetworkHosts.contains(host)) {
          continue;
        }
        violations.add('$rel references non-allowlisted host: $host');
      }
    }
  }

  return violations;
}

/// Registers the source scan as a single `flutter test` case. Call from a
/// consuming app's `test/` directory:
///
/// ```dart
/// import 'package:sumaflow_digest_privacy_core/testing.dart';
///
/// void main() => privacySourceScanTests(allowedHosts: {'huggingface.co'});
/// ```
void privacySourceScanTests({
  List<String> sourceRoots = const <String>['lib'],
  Set<String> allowedHosts = const <String>{},
  Set<String> nonNetworkHosts = kDefaultXmlNamespaceHosts,
  List<String> forbiddenTokens = kDefaultForbiddenNetworkTokens,
  bool Function(String relativePath)? excludeFile,
}) {
  group('PRIVACY: source scan', () {
    test('No networking APIs and no non-allowlisted hosts in source', () {
      final violations = privacySourceScanViolations(
        sourceRoots: sourceRoots,
        allowedHosts: allowedHosts,
        nonNetworkHosts: nonNetworkHosts,
        forbiddenTokens: forbiddenTokens,
        excludeFile: excludeFile,
      );
      expect(
        violations,
        isEmpty,
        reason:
            'PRIVACY VIOLATION: the no-cloud contract (PRD §13, TECHSPEC §10) '
            'is broken by:\n${violations.join('\n')}',
      );
    });
  });
}
