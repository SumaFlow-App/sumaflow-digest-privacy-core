// test/privacy_source_scan_test.dart
//
// Exercises the source scan in both directions against a throwaway source tree.
// The scan is the check that keeps the no-cloud claim falsifiable now that
// INTERNET is legitimately declared, so it gets tested like a product feature.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sumaflow_digest_privacy_core/testing.dart';

void main() {
  late Directory root;

  /// Writes [source] to `root/<name>` and returns nothing; [name] may contain
  /// subdirectories to prove the scan recurses.
  void writeSource(String name, String source) {
    final file = File('${root.path}/$name');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(source);
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('privacy_source_scan_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  List<String> scan({Set<String> allowedHosts = const {'huggingface.co'}}) =>
      privacySourceScanViolations(
        sourceRoots: [root.path],
        allowedHosts: allowedHosts,
      );

  test('on-device source with an allowlisted host is clean', () {
    writeSource('features/ai/model_artifact.dart', '''
const kModelUrl = 'https://huggingface.co/google/gemma-3n/resolve/main/model';
''');
    writeSource('core/storage/database.dart', 'const kDbName = "digest.db";');

    expect(scan(), isEmpty);
  });

  test('flags a non-allowlisted host', () {
    writeSource('features/sync/uploader.dart', '''
const kEndpoint = 'https://api.example.com/v1/documents';
''');

    final violations = scan();
    expect(violations, hasLength(1));
    expect(violations.single, contains('api.example.com'));
    expect(violations.single, contains('non-allowlisted host'));
  });

  test('flags each forbidden networking token', () {
    for (final token in kDefaultForbiddenNetworkTokens) {
      writeSource('net.dart', 'void main() { /* $token */ }');
      expect(
        scan(),
        contains(contains(token)),
        reason: '$token should be caught by the scan',
      );
    }
  });

  test('recurses into nested directories', () {
    writeSource('a/b/c/deep.dart', "import 'package:dio/dio.dart';");
    expect(scan(), contains(contains('package:dio/')));
  });

  test('ignores non-Dart files', () {
    writeSource('notes.md', 'See https://api.example.com for the old design.');
    expect(scan(), isEmpty);
  });

  test('XML namespace hosts are permitted by default', () {
    writeSource('export/docx.dart', '''
const kWordNs =
    'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const kRelNs = 'http://www.w3.org/XML/1998/namespace';
''');
    expect(scan(), isEmpty);
  });

  test('namespace hosts can be narrowed to nothing', () {
    writeSource('export/docx.dart', '''
const kWordNs =
    'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
''');
    expect(
      privacySourceScanViolations(
        sourceRoots: [root.path],
        allowedHosts: const {'huggingface.co'},
        nonNetworkHosts: const {},
      ),
      contains(contains('schemas.openxmlformats.org')),
    );
  });

  test('excludeFile can exempt a path', () {
    writeSource('generated/api.g.dart', "const u = 'https://api.example.com';");
    expect(
      privacySourceScanViolations(
        sourceRoots: [root.path],
        allowedHosts: const {'huggingface.co'},
        excludeFile: (path) => path.endsWith('.g.dart'),
      ),
      isEmpty,
    );
  });

  test('reports every violation in a file, not just the first', () {
    writeSource('bad.dart', '''
import 'package:http/http.dart';
const a = 'https://one.example.com';
const b = 'https://two.example.com';
''');
    expect(scan(), hasLength(3));
  });

  test('a missing source root is itself a violation, not a silent pass', () {
    // Guards the worst failure mode: a scan that inspects nothing and reports
    // clean because the path was wrong.
    final violations = privacySourceScanViolations(
      sourceRoots: ['${root.path}/does_not_exist'],
    );
    expect(violations, hasLength(1));
    expect(violations.single, contains('does not exist'));
  });
}
