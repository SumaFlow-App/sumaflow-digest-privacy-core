// lib/src/privacy_asserting_http_overrides.dart
//
// PRIVACY REGRESSION TEST HELPER — TECHSPEC §10.
// "The privacy test is the most important test in this codebase. A regression
//  that introduces a network call is a P0."
//
// Extracted into the public audit artifact so the helper itself is auditable.
// The consuming app's integration test imports this via
// `package:sumaflow_digest_privacy_core/testing.dart`.

import 'dart:io';

/// An [HttpOverrides] that throws the moment any code attempts to create an
/// [HttpClient]. Install it as `HttpOverrides.global` before booting the app in
/// an integration test; any outbound network attempt then surfaces as a test
/// failure with a stack trace pointing at the offending code.
///
/// It guards the scenarios where SumaFlow Digest expects ZERO network activity
/// — app boot, idle, and the core import → OCR → summarize/extract/redact →
/// export flow. A correctly behaving build never trips it under those scenarios.
///
/// It is deliberately NOT installed around the one flow that legitimately uses
/// the network: the opt-in, Wi-Fi-only, SHA256-verified model download from
/// huggingface.co (the on-device Gemma model — TECHSPEC §2/§3). That download is
/// user-initiated, host-pinned, and disclosed in the privacy whitepaper; it is
/// exercised by its own tests, not under this override. Inference itself runs
/// entirely on-device and never reaches here.
///
/// Two things it structurally cannot see, so do not read a green run as
/// covering them:
///   * Native-layer traffic. [HttpOverrides] governs Dart's [HttpClient] only,
///     and the model download deliberately lives in the native layer behind a
///     platform channel. What native code may contact is pinned by review and
///     by the source scan (privacy_source_scan_tests.dart), not by this class.
///   * Google Play Billing, which reaches Play through the platform's billing
///     client rather than a Dart socket. It carries purchase tokens, never user
///     content — the zero-outbound-content promise holds either way.
class PrivacyAssertingHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw StateError(
      'PRIVACY VIOLATION: SumaFlow Digest attempted to create an HttpClient in '
      'a scenario that must produce zero network calls. The only allowed '
      'outbound flow is the opt-in, Wi-Fi-only, SHA256-verified model download '
      'from huggingface.co, which is not exercised under this override. Find '
      'the offending code and remove it.',
    );
  }
}
