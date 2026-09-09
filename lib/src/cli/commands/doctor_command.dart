import '../../analysis/analysis_pipeline.dart';
import '../../cache/cache_manager.dart';
import '../../config/config_loader.dart';
import '../../rules/findings.dart';
import '../../shared/logger.dart';
import '../../shared/paths.dart';
import '../output/formatter.dart';

/// Handles `flutter_ai_context doctor`.
class DoctorCommand {
  DoctorCommand({
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

    final graph = cache.loadGraph();
    final result = graph == null
        ? await _pipeline.run(
            root: root,
            config: config,
            paths: paths,
            cache: cache,
          )
        : await _pipeline.run(
            root: root,
            config: config,
            paths: paths,
            cache: cache,
            incremental: true,
          );

    _logger.info(OutputFormatter.doctorReport(result.doctorReport));
    return result.doctorReport.findings
            .any((f) => f.severity == FindingSeverity.error)
        ? 1
        : 0;
  }
}
