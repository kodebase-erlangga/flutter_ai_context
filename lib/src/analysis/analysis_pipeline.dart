import '../cache/cache_manager.dart';
import '../config/models/project_config.dart';
import '../discovery/project_discovery.dart';
import '../generators/context_generator.dart';
import '../graph/project_graph.dart';
import '../graph/schema.dart';
import '../inference/architecture_inference.dart';
import '../inference/canonical_reference.dart';
import '../inference/feature_clustering.dart';
import '../inference/state_management_detector.dart';
import '../rules/doctor_engine.dart';
import '../rules/findings.dart';
import '../scanner/dart_scanner.dart';
import '../scanner/detectors/route_detector.dart';
import '../scanner/import_resolver.dart';
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
    final existingGraph = incremental ? cache.loadGraph() : null;

    late ScanResult scanResult;
    late ProjectGraph graph;

    if (incremental && existingGraph != null) {
      final changed =
          filesToScan ?? cache.changedFiles(root, allFiles);
      if (changed.isEmpty) {
        _logger.debug('No changed files, using cached graph');
        graph = existingGraph;
        scanResult = _cachedScanResult(graph, allFiles.length);
      } else {
        final targetFiles = _expandDependentFiles(existingGraph, changed);
        _removeFileNodes(existingGraph, targetFiles);
        scanResult = await _scanner.scan(
          root: root,
          dartFiles: targetFiles,
          allProjectFiles: allFiles,
          existingGraph: existingGraph,
        );
        graph = scanResult.graph;
      }
    } else {
      scanResult = await _scanner.scan(
        root: root,
        dartFiles: filesToScan ?? allFiles,
        allProjectFiles: allFiles,
        existingGraph: null,
      );
      graph = scanResult.graph;
    }

    cache.saveGraph(graph);
    cache.updateFileHashes(root, allFiles);

    final routes = incremental
        ? _routesFromGraph(graph)
        : scanResult.routes;

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
      httpUsageInUi: scanResult.httpUsageInUi,
      screenDirectServiceAccess: scanResult.screenDirectServiceAccess,
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
      routes: routes,
    );

    cache.saveMetadata(
      ScanMetadata(
        lastScan: DateTime.now(),
        filesAnalyzed: allFiles.length,
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

  ScanResult _cachedScanResult(ProjectGraph graph, int totalFiles) {
    return ScanResult(
      graph: graph,
      filesAnalyzed: totalFiles,
      relationshipsResolved: graph.edges.length,
      partialFailures: const [],
    );
  }

  /// Re-scan files that transitively depend on symbols changed in [changedFiles].
  List<String> _expandDependentFiles(
    ProjectGraph graph,
    List<String> changedFiles,
  ) {
    final expanded = changedFiles.toSet();
    var frontier = graph.nodes
        .where((node) => node.file != null && expanded.contains(node.file))
        .map((node) => node.id)
        .toSet();

    final processed = <String>{};
    while (frontier.isNotEmpty) {
      final nextFrontier = <String>{};
      for (final targetId in frontier) {
        if (!processed.add(targetId)) continue;
        for (final edge in graph.edges) {
          if (edge.to != targetId) continue;
          final fromNode = graph.findNode(edge.from);
          final file = fromNode?.file;
          if (file == null) continue;
          if (expanded.add(file)) {
            nextFrontier.addAll(
              graph.nodes
                  .where((node) => node.file == file)
                  .map((node) => node.id),
            );
          }
        }
      }
      frontier = nextFrontier;
    }

    expanded.addAll(_importDependents(graph, expanded));
    return expanded.toList();
  }

  List<String> _importDependents(ProjectGraph graph, Set<String> changedFiles) {
    final importsByFile = <String, List<String>>{};
    for (final node in graph.nodesByType(NodeType.file)) {
      final file = node.file;
      if (file == null) continue;
      importsByFile[file] = (node.metadata['imports'] as List?)
              ?.map((value) => value.toString())
              .toList() ??
          const [];
    }
    return ImportResolver().filesImporting(importsByFile, changedFiles);
  }

  List<DetectedRoute> _routesFromGraph(ProjectGraph graph) {
    return graph.nodesByType(NodeType.route).map((node) {
      final routeType =
          node.metadata['routeType'] as String? ?? 'go_router';
      return DetectedRoute(
        path: node.name,
        screenName: null,
        sourceFile: node.file ?? 'unknown',
        confidence: node.confidence,
        evidence: node.evidence.map((e) => e.description).toList(),
        routeType: routeType,
      );
    }).toList();
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
