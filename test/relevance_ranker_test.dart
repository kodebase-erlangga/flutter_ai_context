import 'dart:io';

import 'package:flutter_ai_context/src/analysis/analysis_pipeline.dart';
import 'package:flutter_ai_context/src/cache/cache_manager.dart';
import 'package:flutter_ai_context/src/cli/commands/context_command.dart';
import 'package:flutter_ai_context/src/config/models/project_config.dart';
import 'package:flutter_ai_context/src/context/relevance_ranker.dart';
import 'package:flutter_ai_context/src/context/scope_suggester.dart';
import 'package:flutter_ai_context/src/generators/context_pack_generator.dart';
import 'package:flutter_ai_context/src/graph/schema.dart';
import 'package:flutter_ai_context/src/shared/paths.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

Future<void> _analyze(String fixture) async {
  final root = fixturePath(fixture);
  final paths = ProjectPaths(root);
  await AnalysisPipeline().run(
    root: root,
    config: ProjectConfig(projectName: fixture),
    paths: paths,
    cache: CacheManager(paths),
  );
}

void main() {
  test('ranks attendance feature with screen-first ordering', () async {
    await _analyze('provider_feature_first');
    final graph = CacheManager(ProjectPaths(fixturePath('provider_feature_first')))
        .loadGraph()!;

    final result = RelevanceRanker().rank(graph, 'Attendance');
    expect(result.nodes, isNotEmpty);
    expect(result.observedFlow, contains('Provider'));

    final screen = result.nodes.firstWhere(
      (node) => node.type == NodeType.screen,
      orElse: () => result.nodes.first,
    );
    expect(screen.file, contains('attendance_screen.dart'));

    final files = result.nodes
        .where((node) => node.file != null)
        .map((node) => node.file)
        .toSet();
    expect(files.length, result.nodes.where((node) => node.file != null).length);
  });

  test('context pack groups files and respects token budget', () async {
    await _analyze('provider_feature_first');
    final graph = CacheManager(ProjectPaths(fixturePath('provider_feature_first')))
        .loadGraph()!;
    final result = RelevanceRanker().rank(graph, 'Attendance');

    final content = ContextPackGenerator().generate(
      scope: 'Attendance',
      graph: graph,
      ranked: result.nodes,
      observedFlow: result.observedFlow,
      maxTokens: 500,
    );

    expect(content, contains('## Screens'));
    expect(content, contains('Observed Flow'));
    expect(content.length, lessThan(2500));
  });

  test('scope suggester proposes close feature names', () async {
    await _analyze('provider_feature_first');
    final graph = CacheManager(ProjectPaths(fixturePath('provider_feature_first')))
        .loadGraph()!;

    final suggestions = ScopeSuggester().suggest(graph, 'attendnce');
    expect(suggestions, contains('Attendance'));
  });

  test('context command writes scoped output file', () async {
    final root = fixturePath('provider_feature_first');
    await _analyze('provider_feature_first');

    final code = ContextCommand().run(root, 'Attendance');
    expect(code, 0);
    expect(
      File(ProjectPaths(root).contextFile('attendance')).existsSync(),
      isTrue,
    );
  });
}
