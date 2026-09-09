import '../../analysis/analysis_pipeline.dart';
import '../../cache/cache_manager.dart';
import '../../config/config_loader.dart';
import '../../shared/logger.dart';
import '../../shared/paths.dart';
import '../output/formatter.dart';

/// Handles `flutter_ai_context scan`.
class ScanCommand {
  ScanCommand({
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

    final result = await _pipeline.run(
      root: root,
      config: config,
      paths: paths,
      cache: cache,
    );

    _logger.info(
      OutputFormatter.scanSummary(
        filesAnalyzed: result.scanResult.filesAnalyzed,
        relationships: result.scanResult.relationshipsResolved,
        features: result.features.length,
        architecture: result.architecture,
      ),
    );

    if (result.scanResult.partialFailures.isNotEmpty &&
        _logger.level != LogLevel.quiet) {
      _logger.warn(
        '${result.scanResult.partialFailures.length} files had partial analysis failures.',
      );
    }

    return 0;
  }
}
