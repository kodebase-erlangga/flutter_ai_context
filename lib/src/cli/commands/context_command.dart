import 'dart:io';

import '../../cache/cache_manager.dart';
import '../../config/config_loader.dart';
import '../../context/relevance_ranker.dart';
import '../../context/scope_suggester.dart';
import '../../generators/context_pack_generator.dart';
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
    final content = generator.generate(
      scope: scope,
      graph: graph,
      ranked: result.nodes,
      observedFlow: result.observedFlow,
      maxTokens: config.contextTokenBudget,
    );

    final outputPath = paths.contextFile(scope.toLowerCase());
    File(outputPath).parent.createSync(recursive: true);
    File(outputPath).writeAsStringSync(content);

    final tokens = generator.estimateTokens(content);
    _logger.info('Context generated: $scope');
    _logger.blank();
    _logger.info('Relevant files:');
    for (final node in result.nodes.where((n) => n.file != null)) {
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
