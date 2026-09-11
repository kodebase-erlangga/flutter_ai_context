import '../../analysis/analysis_pipeline.dart';
import '../../cache/cache_manager.dart';
import '../../config/config_loader.dart';
import '../../discovery/project_discovery.dart';
import '../../graph/schema.dart';
import '../../shared/logger.dart';
import '../../shared/paths.dart';

/// Handles `flutter_ai_context sync`.
class SyncCommand {
  SyncCommand({
    AnalysisPipeline? pipeline,
    ConfigLoader? configLoader,
    ProjectDiscovery? discovery,
    Logger? logger,
  })  : _pipeline = pipeline ?? AnalysisPipeline(logger: logger),
        _configLoader = configLoader ?? ConfigLoader(),
        _discovery = discovery ?? ProjectDiscovery(),
        _logger = logger ?? Logger();

  final AnalysisPipeline _pipeline;
  final ConfigLoader _configLoader;
  final ProjectDiscovery _discovery;
  final Logger _logger;

  Future<int> run(String root) async {
    final paths = ProjectPaths(root);
    final config = _configLoader.load(paths.configFile);
    final cache = CacheManager(paths);
    cache.load();

    if (cache.schemaMismatch) {
      _logger.warn(
        'Cache schema v${cache.cachedSchemaVersion} is incompatible with '
        'v$graphSchemaVersion. Running full rebuild...',
      );
      _logger.info('Tip: use `scan` explicitly after major package upgrades.');
    }

    final discovery = _discovery.discover(root, config);
    final changedCount = cache.countChangedFiles(root, discovery.dartFiles);

    if (changedCount == 0 && !cache.schemaMismatch) {
      _logger.info('No changed files — context already up to date.');
    } else {
      _logger.info(
        changedCount > 0
            ? 'Syncing $changedCount changed file(s)...'
            : 'Rebuilding context...',
      );
    }

    final result = await _pipeline.run(
      root: root,
      config: config,
      paths: paths,
      cache: cache,
      incremental: !cache.schemaMismatch,
    );

    final remaining = cache.countChangedFiles(root, discovery.dartFiles);
    final status = remaining > 0 ? 'STALE' : 'FRESH';

    _logger.blank();
    _logger.success('Context updated');
    _logger.info('Context       : $status');
    _logger.info('Features      : ${result.features.length}');
    if (changedCount > 0) {
      _logger.info('Files synced  : $changedCount');
    }
    _logger.blank();
    _logger.info('Day-to-day: `flutter_ai_context sync`');
    _logger.info('Full rebuild: `flutter_ai_context scan`');
    return 0;
  }
}
