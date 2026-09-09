import 'dart:io';

import 'package:flutter_ai_context/src/analysis/analysis_pipeline.dart';
import 'package:flutter_ai_context/src/cache/cache_manager.dart';
import 'package:flutter_ai_context/src/config/config_loader.dart';
import 'package:flutter_ai_context/src/config/models/project_config.dart';
import 'package:flutter_ai_context/src/shared/paths.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

Future<AnalysisResult> analyzeFixture(
  String name, {
  ProjectConfig? config,
}) async {
  final root = fixturePath(name);
  final paths = ProjectPaths(root);
  final effectiveConfig = config ?? ProjectConfig(projectName: name);
  final cache = CacheManager(paths);
  return AnalysisPipeline().run(
    root: root,
    config: effectiveConfig,
    paths: paths,
    cache: cache,
  );
}

void main() {
  group('Scenario A — Provider feature-first', () {
    test('detects Provider, flow, and Attendance feature', () async {
      final result = await analyzeFixture('provider_feature_first');

      expect(result.stateManagement.primary, 'Provider');
      expect(result.architecture.dominantFlow, contains('Provider'));
      expect(
        result.features.map((f) => f.name),
        contains('Attendance'),
      );
    });
  });

  group('Scenario B — Mixed legacy', () {
    test('detects mixed Provider and Bloc patterns', () async {
      final result = await analyzeFixture('mixed_legacy');

      expect(
        result.stateManagement.distribution.keys,
        containsAll(['Provider', 'Bloc']),
      );
      expect(result.stateManagement.secondary, isNotNull);
    });
  });

  group('Scenario D — Layer-first', () {
    test('clusters attendance files into Attendance feature', () async {
      final result = await analyzeFixture('layer_first');

      expect(
        result.features.map((f) => f.name),
        contains('Attendance'),
      );
    });
  });

  group('Scenario E — Doctor Dio in UI', () {
    test('emits warning for direct Dio usage', () async {
      final result = await analyzeFixture('dio_in_ui');

      expect(
        result.doctorReport.findings.any(
          (f) => f.message.contains('Direct Dio usage'),
        ),
        isTrue,
      );
    });
  });

  group('Scenario C — Declared migration', () {
    test('detects declared vs observed conflict', () async {
      final result = await analyzeFixture(
        'provider_feature_first',
        config: ProjectConfig(
          projectName: 'provider_feature_first',
          stateManagement: 'riverpod',
        ),
      );

      expect(result.doctorReport.declaredArchitecture, 'Riverpod');
      expect(result.doctorReport.observedArchitecture, 'Provider');
      expect(result.doctorReport.interpretation, isNotNull);
    });
  });

  group('Riverpod fixture', () {
    test('detects Riverpod and GoRouter routes', () async {
      final result = await analyzeFixture('riverpod_feature');

      expect(result.stateManagement.primary, 'Riverpod');
      expect(
        result.scanResult.routes.map((r) => r.path),
        containsAll(['/home', '/settings']),
      );
      expect(
          File('${fixturePath('riverpod_feature')}/.ai/routes.md').existsSync(),
          isTrue);
    });
  });

  group('Bloc clean fixture', () {
    test('detects Bloc repository flow', () async {
      final result = await analyzeFixture('bloc_clean');

      expect(result.stateManagement.primary, 'Bloc');
      expect(result.architecture.dominantFlow, contains('Bloc'));
      expect(
        result.features.map((f) => f.name),
        contains('Auth'),
      );
    });
  });

  group('GetX fixture', () {
    test('detects GetX as primary state management', () async {
      final result = await analyzeFixture('getx_feature');

      expect(result.stateManagement.primary, 'GetX');
    });
  });

  group('Migration scenario fixture', () {
    test('reads declared riverpod from config and observes provider dominance',
        () async {
      final root = fixturePath('migration_scenario');
      final paths = ProjectPaths(root);
      final config = ConfigLoader().load(paths.configFile);
      final cache = CacheManager(paths);
      final result = await AnalysisPipeline().run(
        root: root,
        config: config,
        paths: paths,
        cache: cache,
      );

      expect(config.stateManagement, 'riverpod');
      expect(result.doctorReport.declaredArchitecture, 'Riverpod');
      expect(
        result.stateManagement.distribution.containsKey('Provider'),
        isTrue,
      );
      expect(
        result.stateManagement.distribution.containsKey('Riverpod'),
        isTrue,
      );
      expect(result.doctorReport.interpretation, isNotNull);
    });
  });

  group('Semantic resolution', () {
    test('scanner resolves semantic relationships', () async {
      final result = await analyzeFixture('provider_feature_first');

      expect(result.scanResult.relationshipsResolved, greaterThan(0));
    });
  });
}
