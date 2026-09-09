import '../../cache/cache_manager.dart';
import '../../config/config_loader.dart';
import '../../discovery/project_discovery.dart';
import '../../shared/logger.dart';
import '../../shared/paths.dart';
import '../../shared/utils.dart';

/// Handles `flutter_ai_context status`.
class StatusCommand {
  StatusCommand({
    ConfigLoader? configLoader,
    ProjectDiscovery? discovery,
    Logger? logger,
  })  : _configLoader = configLoader ?? ConfigLoader(),
        _discovery = discovery ?? ProjectDiscovery(),
        _logger = logger ?? Logger();

  final ConfigLoader _configLoader;
  final ProjectDiscovery _discovery;
  final Logger _logger;

  int run(String root) {
    final paths = ProjectPaths(root);
    final config = _configLoader.load(paths.configFile);
    final cache = CacheManager(paths);
    cache.load();

    final metadata = cache.loadMetadata();
    final discovery = _discovery.discover(root, config);
    final changedCount = cache.countChangedFiles(root, discovery.dartFiles);

    _logger.info('Flutter AI Context');
    _logger.blank();
    _logger.info('Project       : ${discovery.projectName}');

    if (metadata != null) {
      final ago = Utils.formatDuration(
        DateTime.now().difference(metadata.lastScan),
      );
      _logger.info('Last scan     : $ago');
      _logger.info('Files analyzed: ${metadata.filesAnalyzed}');
      _logger.info('Features      : ${metadata.featureCount}');
    } else {
      _logger.info('Last scan     : never');
    }

    final status = changedCount > 0 ? 'STALE' : 'FRESH';
    _logger.info('Context       : $status');
    if (changedCount > 0) {
      _logger.info('Changed files : $changedCount');
      _logger.blank();
      _logger.info('Run:');
      _logger.info('flutter_ai_context sync');
    }

    return 0;
  }
}
