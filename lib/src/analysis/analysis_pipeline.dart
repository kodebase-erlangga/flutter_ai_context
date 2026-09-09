import '../cache/cache_manager.dart';
import '../config/models/project_config.dart';
import '../discovery/project_discovery.dart';
import '../generators/context_generator.dart';
import '../graph/project_graph.dart';
import '../inference/architecture_inference.dart';
import '../inference/canonical_reference.dart';
import '../inference/feature_clustering.dart';
import '../inference/state_management_detector.dart';
import '../rules/doctor_engine.dart';
import '../rules/findings.dart';
import '../scanner/dart_scanner.dart';
import '../shared/logger.dart';
import '../shared/paths.dart';

/// Full analysis pipeline result.
class AnalysisResult {
  AnalysisResult({
    required this.discovery,
    required this.scanResult,
    required this.stateManagement,
    required this.architecture,
    required this.features,
    required this.canonical,
    required this.doctorReport,
  });

  final DiscoveryResult discovery;
  final ScanResult scanResult;
  final StateManagementResult stateManagement;
  final ArchitectureInference architecture;
  final List<FeatureCluster> features;
  final CanonicalReference? canonical;
  final DoctorReport doctorReport;
}

/// Orchestrates discovery, scanning, inference, and generation.
class AnalysisPipeline {
  AnalysisPipeline({
    ProjectDiscovery? discovery,
    DartScanner? scanner,
    Logger? logger,
  })  : _discovery = discovery ?? ProjectDiscovery(),
        _scanner = scanner ?? DartScanner(logger: logger),
        _logger = logger ?? Logger();

  final ProjectDiscovery _discovery;
  final DartScanner _scanner;
  final Logger _logger;

  Future<AnalysisResult> run({
    required String root,
    required ProjectConfig config,
    required ProjectPaths paths,
    required CacheManager cache,
    List<String>? filesToScan,
    bool incremental = false,
  }) async {
    cache.ensureDirectories();
    cache.load();

    final discovery = _discovery.discover(root, config);
    final allFiles = discovery.dartFiles;
    final targetFiles = filesToScan ??
        (incremental ? cache.changedFiles(root, allFiles) : allFiles);

    if (incremental && targetFiles.isEmpty) {
      _logger.debug('No changed files, using cached graph');
    }

    ProjectGraph? existingGraph;
    if (incremental) {
      existingGraph = cache.loadGraph();
    }

    if (incremental && existingGraph != null && targetFiles.isNotEmpty) {
      _removeFileNodes(existingGraph, targetFiles);
    }

    final scanResult = await _scanner.scan(
      root: root,
      dartFiles: incremental && existingGraph != null ? targetFiles : allFiles,
      allProjectFiles: allFiles,
      existingGraph: incremental ? existingGraph : null,
    );

    final graph = scanResult.graph;
    cache.saveGraph(graph);
    cache.updateFileHashes(root, allFiles);

    final smDetector = StateManagementDetector();
    final stateManagement = smDetector.detect(
      graph: graph,
      signals: scanResult.stateManagementSignals,
      dependencyCandidates: discovery.stateManagementCandidates,
    );

    final archEngine = ArchitectureInferenceEngine();
    final architecture = archEngine.infer(graph);

    final features = FeatureClustering().cluster(graph);
    final canonical = CanonicalReferenceDetector().detect(
      graph,
      architecture.dominantFlow,
    );

    String? interpretation;
    if (config.stateManagement != 'auto' &&
        stateManagement.primary != null &&
        config.stateManagement.toLowerCase() !=
            stateManagement.primary!.toLowerCase()) {
      interpretation =
          'The project appears to be migrating from ${stateManagement.primary} to ${config.stateManagement}.';
    }

    final doctorReport = DoctorEngine().analyze(
      config: config,
      graph: graph,
      stateManagement: stateManagement,
      architecture: architecture,
      dioUsageInUi: scanResult.dioUsageInUi,
    );

    ContextGenerator().generateAll(
      paths: paths,
      config: config,
      discovery: discovery,
      graph: graph,
      stateManagement: stateManagement,
      architecture: architecture,
      features: features,
      canonical: canonical,
      interpretation: interpretation ?? doctorReport.interpretation,
      routes: scanResult.routes,
    );

    cache.saveMetadata(
      ScanMetadata(
        lastScan: DateTime.now(),
        filesAnalyzed: scanResult.filesAnalyzed,
        featureCount: features.length,
        projectName: discovery.projectName,
        isStale: false,
        changedFileCount: 0,
      ),
    );

    return AnalysisResult(
      discovery: discovery,
      scanResult: scanResult,
      stateManagement: stateManagement,
      architecture: architecture,
      features: features,
      canonical: canonical,
      doctorReport: doctorReport,
    );
  }

  void _removeFileNodes(ProjectGraph graph, List<String> files) {
    final fileSet = files.toSet();
    graph.nodes.removeWhere((n) => n.file != null && fileSet.contains(n.file));
    graph.edges.removeWhere((e) {
      final fromNode = graph.findNode(e.from);
      final toNode = graph.findNode(e.to);
      return (fromNode?.file != null && fileSet.contains(fromNode!.file)) ||
          (toNode?.file != null && fileSet.contains(toNode!.file));
    });
  }
}
