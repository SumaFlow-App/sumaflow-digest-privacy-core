// lib/testing.dart
//
// Test-infrastructure entry point for SumaFlow Digest — Privacy Core.
//
// These helpers encode the Digest privacy contract (PRD §13, TECHSPEC §10) as
// machine-checkable assertions. They are imported from consuming apps' `test/`
// and `integration_test/` directories — never from production code. Importing
// this file pulls in flutter_test; importing the runtime barrel
// (sumaflow_digest_privacy_core.dart) does not.

export 'src/privacy_asserting_http_overrides.dart';
export 'src/privacy_manifest_tests.dart';
