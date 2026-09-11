import '../graph/node.dart';
import '../graph/project_graph.dart';
import '../graph/schema.dart';

/// Infers observed architecture flows from feature members and graph edges.
class FlowInference {
  String? inferFeatureFlow(ProjectGraph graph, GraphNode feature) {
    final members = _featureMembers(graph, feature);
    if (members.isEmpty) return null;
    return _inferFromMembers(graph, members);
  }

  String? inferFromMembers(List<GraphNode> members) {
    if (members.isEmpty) return null;
    return _inferFromMembers(null, members);
  }

  Map<String, int> countFeatureFlows(ProjectGraph graph) {
    final counts = <String, int>{};
    for (final feature in graph.nodesByType(NodeType.feature)) {
      final flow = inferFeatureFlow(graph, feature);
      if (flow == null) continue;
      counts[flow] = (counts[flow] ?? 0) + 1;
    }
    return counts;
  }

  List<GraphNode> _featureMembers(ProjectGraph graph, GraphNode feature) {
    final memberIds = <String>{};

    for (final edge in graph.edgesFrom(feature.id)) {
      if (edge.type == EdgeType.contains) {
        memberIds.add(edge.to);
      }
    }
    for (final edge in graph.edgesTo(feature.id)) {
      if (edge.type == EdgeType.belongsToFeature) {
        memberIds.add(edge.from);
      }
    }

    return memberIds
        .map((id) => graph.findNode(id))
        .whereType<GraphNode>()
        .toList();
  }

  String? _inferFromMembers(ProjectGraph? graph, List<GraphNode> members) {
    final presentations = members.where(_isPresentationNode).toList();
    final hasPresentation = presentations.isNotEmpty;
    final entry = _presentationEntryLabel(presentations);

    final getxControllers = members.where(_isGetxStateNode).toList();
    final riverpodNotifiers = members.where(_isRiverpodNotifier).toList();
    final providers = members.where((m) => m.type == NodeType.provider).toList();
    final blocs = members
        .where((m) => m.type == NodeType.bloc || m.type == NodeType.cubit)
        .toList();
    final services = members.where(_isServiceLayer).toList();
    final repositories = members.where(_isRepositoryLayer).toList();
    final hasDataLayer = services.isNotEmpty || repositories.isNotEmpty;

    if (hasPresentation && getxControllers.isNotEmpty && hasDataLayer) {
      return _dataFlowLabel(
        entry,
        'GetX Controller',
        repositories.isNotEmpty,
      );
    }
    if (hasPresentation && riverpodNotifiers.isNotEmpty && hasDataLayer) {
      return _dataFlowLabel(
        entry,
        'Riverpod Notifier',
        repositories.isNotEmpty,
      );
    }
    if (hasPresentation && blocs.isNotEmpty && hasDataLayer) {
      return _dataFlowLabel(entry, 'Bloc', repositories.isNotEmpty);
    }
    if (hasPresentation && providers.isNotEmpty && hasDataLayer) {
      return _dataFlowLabel(entry, 'Provider', repositories.isNotEmpty);
    }

    if (hasPresentation && hasDataLayer) {
      if (_hasStatefulPresentation(presentations)) {
        if (graph != null &&
            _presentationReadsProvider(graph, presentations, members)) {
          return '$entry (StatefulWidget + Provider.read) -> Repository';
        }
        if (graph != null &&
            _presentationCallsRepository(graph, presentations, repositories)) {
          return '$entry (StatefulWidget) -> Repository';
        }
        return '$entry (StatefulWidget) -> Repository';
      }
      if (repositories.isNotEmpty) {
        return '$entry -> Repository';
      }
      if (services.isNotEmpty) {
        return '$entry -> Service';
      }
    }

    if (hasPresentation && providers.isNotEmpty) {
      return '$entry -> Provider';
    }
    if (hasPresentation && getxControllers.isNotEmpty) {
      return '$entry -> GetX Controller';
    }
    if (hasPresentation && blocs.isNotEmpty) {
      return '$entry -> Bloc';
    }

    return null;
  }

  String _dataFlowLabel(String entry, String stateLayer, bool hasRepository) {
    if (hasRepository) {
      return '$entry -> $stateLayer -> Repository';
    }
    return '$entry -> $stateLayer -> Service';
  }

  bool _presentationReadsProvider(
    ProjectGraph graph,
    List<GraphNode> presentations,
    List<GraphNode> members,
  ) {
    for (final screen in presentations) {
      for (final edge in graph.edgesFrom(screen.id)) {
        if (!_isReactiveEdge(edge.type)) continue;
        final target = graph.findNode(edge.to);
        if (target == null) continue;
        if (target.type == NodeType.provider || _isGetxStateNode(target)) {
          return true;
        }
      }
    }
    return members.any((m) => m.type == NodeType.provider || _isGetxStateNode(m));
  }

  bool _presentationCallsRepository(
    ProjectGraph graph,
    List<GraphNode> presentations,
    List<GraphNode> repositories,
  ) {
    if (repositories.isEmpty) return false;
    final repositoryIds = repositories.map((node) => node.id).toSet();
    for (final screen in presentations) {
      for (final edge in graph.edgesFrom(screen.id)) {
        if (repositoryIds.contains(edge.to)) return true;
        final target = graph.findNode(edge.to);
        if (target != null && _isRepositoryLayer(target)) return true;
      }
    }
    return false;
  }

  bool _isReactiveEdge(EdgeType type) {
    return type == EdgeType.calls ||
        type == EdgeType.dependsOn ||
        type == EdgeType.watches ||
        type == EdgeType.reads ||
        type == EdgeType.usesService;
  }

  bool _isGetxStateNode(GraphNode node) {
    if (node.metadata['stateManagementFramework'] == 'getx') return true;
    return node.type == NodeType.notifier && node.name.endsWith('Controller');
  }

  bool _isRiverpodNotifier(GraphNode node) {
    if (node.type != NodeType.notifier) return false;
    return node.metadata['stateManagementFramework'] == 'riverpod';
  }

  bool _isPresentationNode(GraphNode node) {
    if (node.type == NodeType.screen) return true;
    if (node.type != NodeType.widget) return false;
    return node.name.endsWith('Page') ||
        (node.file?.contains('/pages/') ?? false) ||
        (node.file?.endsWith('_page.dart') ?? false);
  }

  bool _hasStatefulPresentation(List<GraphNode> presentations) {
    return presentations.any((node) {
      final superType = node.metadata['superType'] as String?;
      return superType?.contains('StatefulWidget') ?? false;
    });
  }

  String _presentationEntryLabel(List<GraphNode> presentations) {
    if (presentations.any(
      (node) =>
          node.name.endsWith('Screen') ||
          (node.file?.contains('_screen') ?? false) ||
          (node.file?.contains('/screens/') ?? false),
    )) {
      return 'Screen';
    }
    return 'Page';
  }

  bool _isServiceLayer(GraphNode node) {
    return node.type == NodeType.service || node.type == NodeType.apiClient;
  }

  bool _isRepositoryLayer(GraphNode node) {
    return node.type == NodeType.repository;
  }
}
