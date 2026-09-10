import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

import '../graph/edge.dart';
import '../graph/node.dart';
import '../graph/project_graph.dart';
import '../graph/schema.dart';
import '../shared/logger.dart';
import 'classifiers/file_classifier.dart';
import 'detectors/route_detector.dart';
import 'detectors/state_management_signal_detector.dart';
import 'semantic_session.dart';

/// Scan result containing graph and metadata.
class ScanResult {
  ScanResult({
    required this.graph,
    required this.filesAnalyzed,
    required this.relationshipsResolved,
    required this.partialFailures,
    this.stateManagementSignals = const {},
    this.dioUsageInUi = const [],
    this.httpUsageInUi = const [],
    this.screenDirectServiceAccess = const [],
    this.routes = const [],
    this.semanticFilesResolved = 0,
  });

  final ProjectGraph graph;
  final int filesAnalyzed;
  final int relationshipsResolved;
  final List<String> partialFailures;
  final Map<String, int> stateManagementSignals;
  final List<String> dioUsageInUi;
  final List<String> httpUsageInUi;
  final List<String> screenDirectServiceAccess;
  final List<DetectedRoute> routes;
  final int semanticFilesResolved;
}

/// Analyzer-backed Dart source scanner with semantic resolution.
class DartScanner {
  DartScanner({
    FileClassifier? classifier,
    RouteDetector? routeDetector,
    StateManagementSignalDetector? signalDetector,
    Logger? logger,
  })  : _classifier = classifier ?? FileClassifier(),
        _routeDetector = routeDetector ?? RouteDetector(),
        _signalDetector = signalDetector ?? StateManagementSignalDetector(),
        _logger = logger ?? Logger();

  final FileClassifier _classifier;
  final RouteDetector _routeDetector;
  final StateManagementSignalDetector _signalDetector;
  final Logger _logger;

  Future<ScanResult> scan({
    required String root,
    required List<String> dartFiles,
    List<String>? allProjectFiles,
    ProjectGraph? existingGraph,
  }) async {
    final graph = existingGraph ?? ProjectGraph();
    final partialFailures = <String>[];
    final smSignals = StateManagementSignals();
    final dioInUi = <String>[];
    final httpInUi = <String>[];
    final screenDirectService = <String>[];
    final allRoutes = <DetectedRoute>[];
    var relationships = 0;
    var semanticResolved = 0;

    final session = SemanticSession(logger: _logger);
    await session.load(root);

    final indexFiles = allProjectFiles ?? dartFiles;
    final classIndex = session.buildClassIndex(root, indexFiles);
    final symbolRegistry = _SymbolRegistry(classIndex);

    for (final relativePath in dartFiles) {
      final absolutePath = p.join(root, relativePath);
      try {
        final content = File(absolutePath).readAsStringSync();
        final unit = session.getUnit(absolutePath, content);
        if (session.isSemanticallyResolved(absolutePath)) semanticResolved++;

        graph.addNode(
          GraphNode(
            id: NodeId.forFile(relativePath),
            type: NodeType.file,
            name: p.basename(relativePath),
            file: relativePath,
          ),
        );

        final imports = _collectImports(unit);
        smSignals.merge(_signalDetector.detect(unit, imports));

        final routes = _routeDetector.detect(relativePath, unit);
        allRoutes.addAll(routes);

        final visitor = _SemanticClassVisitor(
          filePath: relativePath,
          classifier: _classifier,
          session: session,
          symbolRegistry: symbolRegistry,
          onClass: (node, classification) {
            graph.addNode(node);
            graph.addEdge(
              GraphEdge(
                from: NodeId.forFile(relativePath),
                to: node.id,
                type: EdgeType.contains,
              ),
            );
            _countStateManagement(classification.nodeType, smSignals);
          },
          onRelationship: (fromId, targetId, edgeType, evidence) {
            graph.addEdge(
              GraphEdge(
                from: fromId,
                to: targetId,
                type: edgeType,
                confidence:
                    session.isSemanticallyResolved(absolutePath) ? 0.95 : 0.7,
                evidence: evidence,
              ),
            );
            relationships++;
          },
          onDioInUi: (classId) => dioInUi.add(classId),
          onHttpInUi: (classId) => httpInUi.add(classId),
          onScreenDirectService: (screenId, targetId) {
            screenDirectService.add('$screenId->$targetId');
          },
        );
        unit.accept(visitor);
      } catch (e) {
        partialFailures.add('$relativePath: $e');
        _logger.debug('Failed to analyze $relativePath: $e');
      }
    }

    _routeDetector.applyToGraph(graph, allRoutes);
    _linkFeatureNodes(graph);

    return ScanResult(
      graph: graph,
      filesAnalyzed: dartFiles.length - partialFailures.length,
      relationshipsResolved: relationships,
      partialFailures: partialFailures,
      stateManagementSignals: smSignals.toMap(),
      dioUsageInUi: dioInUi,
      httpUsageInUi: httpInUi,
      screenDirectServiceAccess: screenDirectService,
      routes: allRoutes,
      semanticFilesResolved: semanticResolved,
    );
  }

  void _countStateManagement(NodeType type, StateManagementSignals signals) {
    switch (type) {
      case NodeType.provider:
        signals.provider += 2;
      case NodeType.bloc:
        signals.bloc += 2;
      case NodeType.cubit:
        signals.bloc += 2;
      case NodeType.notifier:
        signals.riverpod += 2;
      default:
        break;
    }
  }

  List<String> _collectImports(CompilationUnit unit) {
    return unit.directives
        .whereType<ImportDirective>()
        .map((d) => d.uri.stringValue ?? '')
        .where((u) => u.isNotEmpty)
        .toList();
  }

  void _linkFeatureNodes(ProjectGraph graph) {
    final features = <String, Set<String>>{};
    for (final node in graph.nodes) {
      if (node.type == NodeType.screen ||
          node.type == NodeType.provider ||
          node.type == NodeType.notifier ||
          node.type == NodeType.bloc ||
          node.type == NodeType.cubit ||
          node.type == NodeType.service ||
          node.type == NodeType.repository ||
          node.type == NodeType.model) {
        final hint = node.metadata['featureHint'] as String?;
        if (hint == null) continue;
        features.putIfAbsent(hint, () => {}).add(node.id);
      }
    }

    for (final entry in features.entries) {
      final featureId = NodeId.forFeature(entry.key);
      graph.addNode(
        GraphNode(
          id: featureId,
          type: NodeType.feature,
          name: entry.key,
          confidence: 0.85,
        ),
      );
      for (final memberId in entry.value) {
        graph.addEdge(
          GraphEdge(from: featureId, to: memberId, type: EdgeType.contains),
        );
        graph.addEdge(
          GraphEdge(
            from: memberId,
            to: featureId,
            type: EdgeType.belongsToFeature,
          ),
        );
      }
    }
  }
}

/// Resolves symbol names to stable graph node IDs.
class _SymbolRegistry {
  _SymbolRegistry(this._classIndex);

  final Map<String, List<String>> _classIndex;

  String resolve(String name, String sourceFile) {
    final locations = _classIndex[name];
    if (locations != null && locations.length == 1) {
      return NodeId.forClass(locations.first, name);
    }
    if (locations != null && locations.contains(sourceFile)) {
      return NodeId.forClass(sourceFile, name);
    }
    return NodeId.forClass(sourceFile, name);
  }
}

class _SemanticClassVisitor extends RecursiveAstVisitor<void> {
  _SemanticClassVisitor({
    required this.filePath,
    required this.classifier,
    required this.session,
    required this.symbolRegistry,
    required this.onClass,
    required this.onRelationship,
    required this.onDioInUi,
    required this.onHttpInUi,
    required this.onScreenDirectService,
  });

  final String filePath;
  final FileClassifier classifier;
  final SemanticSession session;
  final _SymbolRegistry symbolRegistry;
  final void Function(GraphNode node, ClassificationResult classification)
      onClass;
  final void Function(
    String fromId,
    String targetId,
    EdgeType type,
    List<String> evidence,
  ) onRelationship;
  final void Function(String classId) onDioInUi;
  final void Function(String classId) onHttpInUi;
  final void Function(String screenId, String targetId) onScreenDirectService;

  String? _currentClassId;
  NodeType? _currentClassType;
  List<String> _imports = [];

  @override
  void visitCompilationUnit(CompilationUnit node) {
    _imports = node.directives
        .whereType<ImportDirective>()
        .map((d) => d.uri.stringValue ?? '')
        .toList();
    super.visitCompilationUnit(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final className = node.name.lexeme;
    final superClass = session.resolveSuperType(node);
    final implemented =
        node.implementsClause?.interfaces.map((i) => i.toString()).toList() ??
            [];
    final mixins =
        node.withClause?.mixinTypes.map((m) => m.toString()).toList() ?? [];

    final methods = <String>[];
    var hasBuild = false;
    for (final member in node.members) {
      if (member is MethodDeclaration) {
        methods.add(member.name.lexeme);
        if (member.name.lexeme == 'build') hasBuild = true;
      }
    }

    final hasRiverpodAnnotation = node.metadata.any((a) {
      final name = a.name.name;
      return name == 'riverpod' || name.endsWith('Riverpod');
    });

    final classification = classifier.classifyClass(
      filePath: filePath,
      className: className,
      superClass: superClass,
      implementedTypes: implemented,
      mixins: mixins,
      hasBuildMethod: hasBuild,
      methodNames: methods,
      imports: _imports,
      hasRiverpodAnnotation: hasRiverpodAnnotation,
    );

    final nodeId = NodeId.forClass(filePath, className);
    _currentClassId = nodeId;
    _currentClassType = classification.nodeType;

    onClass(
      GraphNode(
        id: nodeId,
        type: classification.nodeType,
        name: className,
        file: filePath,
        confidence: classification.confidence,
        evidence: classification.evidence,
        metadata: {
          if (classification.featureHint != null)
            'featureHint': classification.featureHint,
          if (classification.stateManagementFramework != null)
            'stateManagementFramework': classification.stateManagementFramework,
        },
      ),
      classification,
    );

    super.visitClassDeclaration(node);
    _currentClassId = null;
    _currentClassType = null;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_currentClassId == null) {
      super.visitMethodInvocation(node);
      return;
    }

    final methodName = node.methodName.name;
    final ctorType = session.resolveConstructorCall(node);
    if (ctorType != null && _isUiLayer(_currentClassType)) {
      if (_isDioType(ctorType)) {
        onDioInUi(_currentClassId!);
      } else if (_isHttpClientType(ctorType)) {
        onHttpInUi(_currentClassId!);
      }
    }

    if (methodName == 'notifyListeners') {
      onRelationship(
        _currentClassId!,
        symbolRegistry.resolve('ChangeNotifier', filePath),
        EdgeType.dependsOn,
        ['notifyListeners()'],
      );
    }

    final target = session.resolveInvocationTarget(node);
    if (target != null && methodName.isNotEmpty) {
      final targetId = symbolRegistry.resolve(target, filePath);
      final edgeType = _edgeTypeForCall(methodName, node);
      onRelationship(
        _currentClassId!,
        targetId,
        edgeType,
        ['$target.$methodName()'],
      );
      if (_currentClassType == NodeType.screen &&
          _isServiceLikeTarget(target, methodName)) {
        onScreenDirectService(_currentClassId!, targetId);
      }
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_currentClassId != null) {
      final typeName = session.resolveConstructedType(node) ?? '';
      if (_isUiLayer(_currentClassType)) {
        if (_isDioType(typeName)) {
          onDioInUi(_currentClassId!);
        } else if (_isHttpClientType(typeName)) {
          onHttpInUi(_currentClassId!);
        }
      }
      if (typeName.isNotEmpty) {
        onRelationship(
          _currentClassId!,
          symbolRegistry.resolve(typeName, filePath),
          EdgeType.dependsOn,
          ['creates $typeName'],
        );
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  EdgeType _edgeTypeForCall(String methodName, MethodInvocation node) {
    if (methodName == 'watch' ||
        methodName == 'read' ||
        methodName == 'listen') {
      final target = node.target?.toString() ?? '';
      if (target == 'ref' || target.contains('context')) {
        return EdgeType.watches;
      }
    }
    return EdgeType.calls;
  }

  bool _isUiLayer(NodeType? type) =>
      type == NodeType.screen || type == NodeType.widget;

  bool _isDioType(String typeName) => typeName.contains('Dio');

  bool _isHttpClientType(String typeName) =>
      typeName == 'Client' || typeName.contains('http.Client');

  bool _isServiceLikeTarget(String target, String methodName) {
    if (methodName == 'get' || methodName == 'post' || methodName == 'fetch') {
      return true;
    }
    return target.endsWith('Service') ||
        target.endsWith('Repository') ||
        target.endsWith('Api');
  }
}
