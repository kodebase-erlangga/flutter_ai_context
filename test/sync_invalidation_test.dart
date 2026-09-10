import 'dart:io';

import 'package:flutter_ai_context/src/analysis/analysis_pipeline.dart';
import 'package:flutter_ai_context/src/cache/cache_manager.dart';
import 'package:flutter_ai_context/src/config/models/project_config.dart';
import 'package:flutter_ai_context/src/graph/schema.dart';
import 'package:flutter_ai_context/src/shared/paths.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  test('transitive sync invalidation re-scans dependent files', () async {
    final root = fixturePath('provider_feature_first');
    final paths = ProjectPaths(root);
    final config = ProjectConfig(projectName: 'provider_feature_first');
    final cache = CacheManager(paths);

    await AnalysisPipeline().run(
      root: root,
      config: config,
      paths: paths,
      cache: cache,
    );

    final servicePath = p.join(
      root,
      'lib',
      'features',
      'attendance',
      'attendance_service.dart',
    );
    final screenPath = p.join(
      root,
      'lib',
      'features',
      'attendance',
      'attendance_screen.dart',
    );

    final originalService = File(servicePath).readAsStringSync();
    final originalScreen = File(screenPath).readAsStringSync();
    File(servicePath).writeAsStringSync('$originalService\n// touched\n');

    await AnalysisPipeline().run(
      root: root,
      config: config,
      paths: paths,
      cache: cache,
      incremental: true,
    );

    final graph = cache.loadGraph()!;
    expect(
      graph.nodesByType(NodeType.feature).map((node) => node.name),
      contains('Attendance'),
    );
    expect(
      graph.nodes.any((node) => node.name == 'AttendanceService'),
      isTrue,
    );

    File(servicePath).writeAsStringSync(originalService);
    File(screenPath).writeAsStringSync(originalScreen);
  });
}
