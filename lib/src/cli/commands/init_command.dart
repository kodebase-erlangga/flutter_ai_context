import 'dart:io';

import '../../analysis/analysis_pipeline.dart';
import '../../cache/cache_manager.dart';
import '../../config/config_loader.dart';
import '../../config/models/project_config.dart';
import '../../shared/logger.dart';
import '../../shared/paths.dart';
import '../../shared/utils.dart';
import '../output/formatter.dart';

/// Handles `flutter_ai_context init`.
class InitCommand {
  InitCommand({
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
    _logger.info('Flutter AI Context');
    _logger.blank();

    if (!Utils.isDartProject(root)) {
      _logger.error('Not a Dart/Flutter project.');
      return 1;
    }

    _logger.success('Flutter project detected');

    final paths = ProjectPaths(root);
    final config = ProjectConfig(projectName: _readProjectName(root));

    if (!File(paths.configFile).existsSync()) {
      _configLoader.writeDefault(paths.configFile, config);
      _logger.success('Created flutter_ai_context.yaml');
    }

    _logger.success('Scanning project structure');
    _logger.success('Detecting dependencies');
    _logger.success('Analyzing Dart code');
    _logger.success('Detecting architecture');
    _logger.success('Building project knowledge graph');
    _logger.success('Generating AI context');

    final cache = CacheManager(paths);
    final result = await _pipeline.run(
      root: root,
      config: config,
      paths: paths,
      cache: cache,
    );

    if (result.stateManagement.distribution.length > 1) {
      _logger.warn('Multiple state management patterns detected');
      _logger.blank();
      for (final entry in result.stateManagement.distribution.entries) {
        _logger.info(
          '${entry.key.padRight(9)}: ${entry.value.toStringAsFixed(0)}%',
        );
      }
      _logger.blank();
      _logger.info(
        '${result.stateManagement.primary} selected as the dominant observed pattern.',
      );
      _logger.info(
        'Review flutter_ai_context.yaml if this is not the intended architecture.',
      );
      _logger.blank();
    }

    _logger.info(
      OutputFormatter.initSummary(
        projectName: result.discovery.projectName,
        stateManagement: result.stateManagement,
        networking: result.discovery.networking,
        routing: result.discovery.routing,
        architectureStyle: result.discovery.architectureStyle,
      ),
    );

    _logger.blank();
    _logger.info('AI context initialized successfully.');
    return 0;
  }

  String _readProjectName(String root) {
    final pubspec = File(pathsJoin(root, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return 'my_flutter_app';
    final match = RegExp(r'^name:\s*(\S+)', multiLine: true)
        .firstMatch(pubspec.readAsStringSync());
    return match?.group(1) ?? 'my_flutter_app';
  }

  String pathsJoin(String a, String b) => '$a${Platform.pathSeparator}$b';
}
