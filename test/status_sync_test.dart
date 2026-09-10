import 'dart:io';

import 'package:flutter_ai_context/src/analysis/analysis_pipeline.dart';
import 'package:flutter_ai_context/src/cache/cache_manager.dart';
import 'package:flutter_ai_context/src/cli/commands/status_command.dart';
import 'package:flutter_ai_context/src/config/models/project_config.dart';
import 'package:flutter_ai_context/src/shared/logger.dart';
import 'package:flutter_ai_context/src/shared/paths.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  test('status reports non-zero files analyzed after init', () async {
    final root = fixturePath('provider_feature_first');
    final paths = ProjectPaths(root);
    final cache = CacheManager(paths);

    await AnalysisPipeline().run(
      root: root,
      config: ProjectConfig(projectName: 'provider_feature_first'),
      paths: paths,
      cache: cache,
    );

    final metadata = cache.loadMetadata();
    expect(metadata, isNotNull);
    expect(metadata!.filesAnalyzed, greaterThan(0));

    final output = StringBuffer();
    StatusCommand(
      logger: _CapturingLogger(output),
    ).run(root);

    expect(output.toString(), contains('Files analyzed: ${metadata.filesAnalyzed}'));
  });

  test('sync with no changes preserves files analyzed count', () async {
    final root = fixturePath('provider_feature_first');
    final paths = ProjectPaths(root);
    final cache = CacheManager(paths);
    final config = ProjectConfig(projectName: 'provider_feature_first');

    await AnalysisPipeline().run(
      root: root,
      config: config,
      paths: paths,
      cache: cache,
    );
    final afterInit = cache.loadMetadata()!.filesAnalyzed;

    await AnalysisPipeline().run(
      root: root,
      config: config,
      paths: paths,
      cache: cache,
      incremental: true,
    );

    expect(cache.loadMetadata()!.filesAnalyzed, afterInit);
    expect(cache.loadMetadata()!.filesAnalyzed, greaterThan(0));
  });

  test('features.md members are deduplicated', () async {
    final root = fixturePath('provider_feature_first');
    final paths = ProjectPaths(root);
    final cache = CacheManager(paths);

    await AnalysisPipeline().run(
      root: root,
      config: ProjectConfig(projectName: 'provider_feature_first'),
      paths: paths,
      cache: cache,
    );

    final featuresMd =
        File(paths.aiFile('features.md')).readAsStringSync().split('\n');
    final bulletLines =
        featuresMd.where((line) => line.startsWith('- `')).toList();
    final uniqueBullets = bulletLines.toSet();
    expect(uniqueBullets.length, bulletLines.length);
  });
}

class _CapturingLogger extends Logger {
  _CapturingLogger(this._buffer) : super(level: LogLevel.quiet);

  final StringBuffer _buffer;

  @override
  void info(String message) => _buffer.writeln(message);

  @override
  void blank() => _buffer.writeln();
}
