import 'package:flutter_ai_context/src/analysis/analysis_pipeline.dart';
import 'package:flutter_ai_context/src/cache/cache_manager.dart';
import 'package:flutter_ai_context/src/config/models/project_config.dart';
import 'package:flutter_ai_context/src/shared/paths.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  test('provider_feature_first scans within benchmark budget', () async {
    final root = fixturePath('provider_feature_first');
    final paths = ProjectPaths(root);
    final cache = CacheManager(paths);

    final stopwatch = Stopwatch()..start();
    await AnalysisPipeline().run(
      root: root,
      config: ProjectConfig(projectName: 'provider_feature_first'),
      paths: paths,
      cache: cache,
    );
    stopwatch.stop();

    expect(stopwatch.elapsedMilliseconds, lessThan(30000));
  });

  test('getx_pages scans within benchmark budget', () async {
    final root = fixturePath('getx_pages');
    final paths = ProjectPaths(root);
    final cache = CacheManager(paths);

    final stopwatch = Stopwatch()..start();
    final result = await AnalysisPipeline().run(
      root: root,
      config: ProjectConfig(projectName: 'getx_pages'),
      paths: paths,
      cache: cache,
    );
    stopwatch.stop();

    expect(stopwatch.elapsedMilliseconds, lessThan(35000));
    expect(result.scanResult.filesAnalyzed, 24);
    expect(result.features.length, greaterThanOrEqualTo(8));
    expect(result.stateManagement.primary?.toLowerCase(), contains('getx'));
  });

  test('mixed_legacy scans within benchmark budget', () async {
    final root = fixturePath('mixed_legacy');
    final paths = ProjectPaths(root);
    final cache = CacheManager(paths);

    final stopwatch = Stopwatch()..start();
    await AnalysisPipeline().run(
      root: root,
      config: ProjectConfig(projectName: 'mixed_legacy'),
      paths: paths,
      cache: cache,
    );
    stopwatch.stop();

    expect(stopwatch.elapsedMilliseconds, lessThan(30000));
  });
}
