import 'dart:io';

import '../../cache/cache_manager.dart';
import '../../config/config_loader.dart';
import '../../context/relevance_ranker.dart';
import '../../context/scope_suggester.dart';
import '../../generators/context_pack_generator.dart';
import '../../graph/schema.dart';
import '../../shared/logger.dart';
import '../../shared/paths.dart';

/// Handles `flutter_ai_context context <scope>`.
class ContextCommand {
  ContextCommand({
    ConfigLoader? configLoader,
    Logger? logger,
  })  : _configLoader = configLoader ?? ConfigLoader(),
        _logger = logger ?? Logger();

  final ConfigLoader _configLoader;
  final Logger _logger;

  int listScopes(String root) {
    final cache = CacheManager(ProjectPaths(root));
    final graph = cache.loadGraph();
    if (graph == null) {
      _logger.error(
        'No project graph found. Run `flutter_ai_context scan` first.',
      );
      return 1;
    }

    final features = graph.nodesByType(NodeType.feature).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    _logger.info('Available context scopes:');
    _logger.blank();
    if (features.isEmpty) {
      _logger.warn('No feature scopes detected yet.');
      return 0;
    }

    for (final feature in features) {
      final members = graph
          .edgesFrom(feature.id)
          .where((edge) => edge.type == EdgeType.contains)
          .length;
      _logger.info('- ${feature.name} ($members members)');
    }
    _logger.blank();
    _logger.info('Usage: flutter_ai_context context <scope>');
    return 0;
  }

  int run(String root, String scope) {
    final paths = ProjectPaths(root);
    final config = _configLoader.load(paths.configFile);
    final cache = CacheManager(paths);
    final graph = cache.loadGraph();

    if (graph == null) {
      _logger.error(
        'No project graph found. Run `flutter_ai_context scan` first.',
      );
      return 1;
    }

    final ranker = RelevanceRanker();
    final result = ranker.rank(graph, scope);
    if (result.nodes.isEmpty) {
      _logger.warn('No context found for scope: $scope');
      final suggestions = ScopeSuggester().suggest(graph, scope);
      if (suggestions.isNotEmpty) {
        _logger.blank();
        _logger.info('Did you mean: ${suggestions.join(', ')}?');
      }
      return 1;
    }

    final generator = ContextPackGenerator();
    final pack = generator.build(
      scope: scope,
      graph: graph,
      ranked: result.nodes,
      observedFlow: result.observedFlow,
      maxTokens: config.contextTokenBudget,
    );

    final outputPath = paths.contextFile(scope.toLowerCase());
    File(outputPath).parent.createSync(recursive: true);
    File(outputPath).writeAsStringSync(pack.content);

    final tokens = generator.estimateTokens(pack.content);
    _logger.info('Context generated: $scope');
    _logger.blank();
    _logger.info('Relevant files:');
    for (final node in pack.selectedNodes.where((n) => n.file != null)) {
      _logger.info('- ${node.file!.split('/').last}');
    }
    if (result.observedFlow != null) {
      _logger.blank();
      _logger.info('Observed flow: ${result.observedFlow}');
    }
    _logger.blank();
    _logger.info('Estimated context size:');
    _logger.info('$tokens tokens');

    return 0;
  }
}
