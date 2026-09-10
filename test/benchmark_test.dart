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
