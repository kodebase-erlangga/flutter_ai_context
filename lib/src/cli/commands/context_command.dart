import 'dart:io';

import '../../cache/cache_manager.dart';
import '../../config/config_loader.dart';
import '../../context/relevance_ranker.dart';
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
    _configLoader.load(paths.configFile);
    final cache = CacheManager(paths);
    final graph = cache.loadGraph();

    if (graph == null) {
      _logger.error(
        'No project graph found. Run `flutter_ai_context scan` first.',
      );
      return 1;
    }

    final ranked = RelevanceRanker().rank(graph, scope);
    if (ranked.isEmpty) {
      _logger.warn('No context found for scope: $scope');
      return 1;
    }

    final generator = ContextPackGenerator();
    final content = generator.generate(
      scope: scope,
      graph: graph,
      ranked: ranked,
    );

    final outputPath = paths.contextFile(scope.toLowerCase());
    File(outputPath).parent.createSync(recursive: true);
    File(outputPath).writeAsStringSync(content);

    final tokens = generator.estimateTokens(content);
    _logger.info('Context generated: $scope');
    _logger.blank();
    _logger.info('Relevant files:');
    for (final node in ranked.where((n) => n.file != null)) {
      _logger.info('- ${node.file!.split('/').last}');
    }
    _logger.blank();
    _logger.info('Estimated context size:');
    _logger.info('$tokens tokens');

    return 0;
  }
}
