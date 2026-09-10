import 'dart:io';

import 'package:flutter_ai_context/src/context/relevance_ranker.dart';
import 'package:flutter_ai_context/src/generators/architecture_md_generator.dart';
import 'package:flutter_ai_context/src/generators/context_pack_generator.dart';
import 'package:flutter_ai_context/src/generators/routes_md_generator.dart';
import 'package:test/test.dart';

import 'integration_test.dart' show analyzeFixture;

void main() {
  final goldensDir = Directory('${Directory.current.path}/test/goldens');
  if (!goldensDir.existsSync()) {
    goldensDir.createSync(recursive: true);
  }

  test('architecture.md golden for provider_feature_first', () async {
    final result = await analyzeFixture('provider_feature_first');
    final content = ArchitectureMdGenerator().generate(
      stateManagement: result.stateManagement,
      architecture: result.architecture,
    );

    final goldenPath =
        '${goldensDir.path}/provider_feature_first_architecture.md';
    _assertGolden(goldenPath, content);
  });

  test('routes.md golden for riverpod_feature', () async {
    final result = await analyzeFixture('riverpod_feature');
    final content = RoutesMdGenerator().generate(result.scanResult.routes);

    final goldenPath = '${goldensDir.path}/riverpod_feature_routes.md';
    _assertGolden(goldenPath, content);
  });

  test('context pack golden for provider attendance', () async {
    final result = await analyzeFixture('provider_feature_first');
    final rank = RelevanceRanker().rank(result.scanResult.graph, 'Attendance');
    final content = ContextPackGenerator().generate(
      scope: 'Attendance',
      graph: result.scanResult.graph,
      ranked: rank.nodes,
      observedFlow: rank.observedFlow,
      maxTokens: 2000,
    );

    final goldenPath = '${goldensDir.path}/provider_attendance_context.md';
    _assertGolden(goldenPath, content);
  });

  test('architecture.md golden for bloc_clean', () async {
    final result = await analyzeFixture('bloc_clean');
    final content = ArchitectureMdGenerator().generate(
      stateManagement: result.stateManagement,
      architecture: result.architecture,
    );

    final goldenPath = '${goldensDir.path}/bloc_clean_architecture.md';
    _assertGolden(goldenPath, content);
  });
}

void _assertGolden(String goldenPath, String actual) {
  final goldenFile = File(goldenPath);
  final normalizedActual = _normalizeGolden(actual);
  if (!goldenFile.existsSync()) {
    goldenFile.writeAsStringSync(normalizedActual);
    fail(
      'Golden file created at $goldenPath. Re-run tests to verify.',
    );
  }
  expect(
    normalizedActual,
    equals(_normalizeGolden(goldenFile.readAsStringSync())),
    reason: 'Golden mismatch for $goldenPath',
  );
}

/// Normalizes volatile evidence counts for stable golden comparison.
String _normalizeGolden(String content) {
  return content
      .replaceAll('\r\n', '\n')
      .replaceAllMapped(
        RegExp(r'- \d+ (Provider|Bloc|Riverpod|GetX) indicators'),
        (m) => '- N ${m.group(1)} indicators',
      );
}
