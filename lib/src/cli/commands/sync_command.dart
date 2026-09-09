import '../../analysis/analysis_pipeline.dart';
import '../../cache/cache_manager.dart';
import '../../config/config_loader.dart';
import '../../shared/logger.dart';
import '../../shared/paths.dart';

/// Handles `flutter_ai_context sync`.
class SyncCommand {
  SyncCommand({
    AnalysisPipeline? pipeline,
    ConfigLoader? configLoader,
    Logger? logger,
  })  : _pipeline = pipeline ?? AnalysisPipeline(logger: logger),
        _configLoader = configLoader ?? ConfigLoader(),
        _logger = logger ?? Logger();

  final AnalysisPipeline _pipeline;
  final ConfigLoader _configLoader;
  final Logger _logger;

  Future<int> run(String root) async {
    final paths = ProjectPaths(root);
    final config = _configLoader.load(paths.configFile);
    final cache = CacheManager(paths);
    cache.load();
    _logger.info('Syncing changed files...');

    final result = await _pipeline.run(
      root: root,
      config: config,
      paths: paths,
      cache: cache,
      incremental: true,
    );

    _logger.success('Context updated');
    _logger.info('Features: ${result.features.length}');
    return 0;
  }
}
