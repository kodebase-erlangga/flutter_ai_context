import '../graph/node.dart';
import '../graph/project_graph.dart';
import '../graph/schema.dart';

/// Ranked file/node for context packs.
class RankedNode {
  RankedNode({
    required this.id,
    required this.name,
    required this.file,
    required this.score,
    required this.reason,
    this.type,
    this.hop = 0,
  });

  final String id;
  final String name;
  final String? file;
  final double score;
  final String reason;
  final NodeType? type;
  final int hop;
}

/// Result of ranking nodes for a context scope.
class RankResult {
  RankResult({
    required this.nodes,
    this.observedFlow,
  });

  final List<RankedNode> nodes;
  final String? observedFlow;
}

/// Ranks nodes by graph distance, role, and scope relevance.
class RelevanceRanker {
  static const _forwardEdges = {
    EdgeType.contains,
    EdgeType.calls,
    EdgeType.dependsOn,
    EdgeType.watches,
    EdgeType.reads,
    EdgeType.usesService,
    EdgeType.mapsToRoute,
  };

  RankResult rank(ProjectGraph graph, String scope) {
    final normalizedScope = scope.toLowerCase();
    final scores = <String, RankedNode>{};

    GraphNode? featureNode;
    for (final node in graph.nodesByType(NodeType.feature)) {
      if (node.name.toLowerCase() == normalizedScope) {
        featureNode = node;
        break;
      }
    }

    if (featureNode != null) {
      for (final edge in graph.edgesFrom(featureNode.id)) {
        if (edge.type != EdgeType.contains) continue;
        _walkFromNode(
          graph: graph,
          startId: edge.to,
          scores: scores,
          baseScore: 1.0,
          reason: 'direct feature membership',
          maxDepth: 2,
          featureScope: normalizedScope,
        );
      }

      _seedSharedImports(graph, scores, normalizedScope);

      return RankResult(
        nodes: _sortedUnique(scores),
        observedFlow: _inferFeatureFlow(graph, featureNode),
      );
    }

    final seeds = graph.nodes.where((node) {
      return node.name.toLowerCase().contains(normalizedScope) ||
          (node.file?.toLowerCase().contains(normalizedScope) ?? false);
    });

    for (final seed in seeds) {
      _walkFromNode(
        graph: graph,
        startId: seed.id,
        scores: scores,
        baseScore: 0.85,
        reason: 'scope name match',
        maxDepth: 2,
        featureScope: normalizedScope,
      );
    }

    _seedSharedImports(graph, scores, normalizedScope);

    return RankResult(nodes: _sortedUnique(scores));
  }

  void _seedSharedImports(
    ProjectGraph graph,
    Map<String, RankedNode> scores,
    String featureScope,
  ) {
    final featureFiles = scores.values
        .map((node) => node.file)
        .whereType<String>()
        .toSet();

    for (final file in featureFiles) {
      final fileId = NodeId.forFile(file);
      for (final edge in graph.edgesFrom(fileId)) {
        if (edge.type != EdgeType.imports) continue;
        final imported = graph.findNode(edge.to);
        final importedPath = imported?.file;
        if (importedPath == null || !_isSharedPath(importedPath)) continue;

        for (final contained in graph.edgesFrom(edge.to)) {
          if (contained.type != EdgeType.contains) continue;
          _walkFromNode(
            graph: graph,
            startId: contained.to,
            scores: scores,
            baseScore: 0.72,
            reason: 'shared import from feature',
            maxDepth: 1,
            featureScope: featureScope,
            allowShared: true,
          );
        }
      }
    }
  }

  List<RankedNode> _sortedUnique(Map<String, RankedNode> scores) {
    final byFile = <String, RankedNode>{};
    final withoutFile = <RankedNode>[];

    for (final node in scores.values) {
      if (node.file == null) {
        withoutFile.add(node);
        continue;
      }
      final existing = byFile[node.file!];
      if (existing == null || _prefersNode(node, existing)) {
        byFile[node.file!] = node;
      }
    }

    final merged = [...byFile.values, ...withoutFile];
    merged.sort((a, b) => b.score.compareTo(a.score));
    return merged;
  }

  bool _prefersNode(RankedNode candidate, RankedNode incumbent) {
    if (candidate.score > incumbent.score + 0.05) return true;
    if (incumbent.score > candidate.score + 0.05) return false;
    return _nameFileAffinity(candidate) > _nameFileAffinity(incumbent);
  }

  int _nameFileAffinity(RankedNode node) {
    final file = node.file;
    if (file == null) return 0;
    if (node.name.startsWith('_')) return -5;

    final base = file.split('/').last.replaceAll('.dart', '').toLowerCase();
    final className = node.name.toLowerCase();
    final normalizedBase = base.replaceAll('_', '');
    final normalizedClass = className.replaceAll('_', '');

    if (normalizedClass == normalizedBase) return 10;
    if (normalizedBase.contains(normalizedClass) ||
        normalizedClass.contains(normalizedBase)) {
      return 6;
    }
    return 0;
  }

  void _walkFromNode({
    required ProjectGraph graph,
    required String startId,
    required Map<String, RankedNode> scores,
    required double baseScore,
    required String reason,
    required int maxDepth,
    String? featureScope,
    bool allowShared = false,
  }) {
    final queue = <({String id, int depth})>[(id: startId, depth: 0)];
    final visited = <String>{};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (!visited.add(current.id)) continue;
      if (current.depth > maxDepth) continue;

      final node = graph.findNode(current.id);
      if (node == null) continue;

      final inFeatureScope = _matchesFeatureScope(node, featureScope);
      final viaShared = allowShared && _isSharedPath(node.file ?? '');
      if (featureScope != null && !inFeatureScope && !viaShared) continue;

      final roleBoost = _roleBoost(node.type);
      final hopPenalty = current.depth * 0.15;
      final score = (baseScore + roleBoost - hopPenalty).clamp(0.1, 1.2);

      final candidate = RankedNode(
        id: node.id,
        name: node.name,
        file: node.file,
        score: score,
        reason: current.depth == 0 ? reason : '$reason (+$current.depth hop)',
        type: node.type,
        hop: current.depth,
      );

      final existing = scores[node.id];
      if (existing == null || candidate.score > existing.score) {
        scores[node.id] = candidate;
      }

      if (current.depth >= maxDepth) continue;

      for (final edge in graph.edgesFrom(node.id)) {
        if (!_forwardEdges.contains(edge.type)) continue;
        queue.add((id: edge.to, depth: current.depth + 1));
      }
    }
  }

  bool _matchesFeatureScope(GraphNode node, String? featureScope) {
    if (featureScope == null) return true;
    final file = node.file?.toLowerCase();
    if (file == null) return true;
    if (file.contains('/features/$featureScope/')) return true;
    if (file.contains('/modules/$featureScope/')) return true;
    if (file.contains('/$featureScope/')) return true;
    return false;
  }

  bool _isSharedPath(String file) {
    final normalized = file.toLowerCase();
    return normalized.startsWith('lib/core/') ||
        normalized.startsWith('lib/shared/') ||
        normalized.contains('/core/') ||
        normalized.contains('/shared/');
  }

  double _roleBoost(NodeType type) {
    switch (type) {
      case NodeType.screen:
        return 0.15;
      case NodeType.provider:
      case NodeType.bloc:
      case NodeType.cubit:
      case NodeType.notifier:
        return 0.12;
      case NodeType.service:
      case NodeType.repository:
      case NodeType.apiClient:
        return 0.08;
      case NodeType.model:
      case NodeType.entity:
        return 0.05;
      case NodeType.route:
        return 0.04;
      default:
        return 0.0;
    }
  }

  String? _inferFeatureFlow(ProjectGraph graph, GraphNode feature) {
    final members = graph
        .edgesFrom(feature.id)
        .where((edge) => edge.type == EdgeType.contains)
        .map((edge) => graph.findNode(edge.to))
        .whereType<GraphNode>()
        .toList();

    final hasPresentation = members.any(_isPresentationNode);
    final hasProvider = members.any((m) => m.type == NodeType.provider);
    final hasNotifier = members.any((m) => m.type == NodeType.notifier);
    final hasGetxController = members.any(_isGetxStateNode);
    final hasBloc = members.any(
      (m) => m.type == NodeType.bloc || m.type == NodeType.cubit,
    );
    final hasService = members.any(
      (m) =>
          m.type == NodeType.service ||
          m.type == NodeType.repository ||
          m.type == NodeType.apiClient,
    );

    final entry = _presentationEntryLabel(members);
    if (hasPresentation && hasGetxController && hasService) {
      return '$entry -> GetX Controller -> Repository';
    }
    if (hasPresentation && hasNotifier && hasService) {
      return '$entry -> Riverpod Notifier -> Repository';
    }
    if (hasPresentation && hasBloc && hasService) {
      return '$entry -> Bloc -> Repository';
    }
    if (hasPresentation && hasProvider && hasService) {
      return '$entry -> Provider -> Service';
    }
    if (hasPresentation && hasProvider) return '$entry -> Provider';
    if (hasPresentation && hasBloc) return '$entry -> Bloc';
    return null;
  }

  bool _isGetxStateNode(GraphNode node) {
    if (node.metadata['stateManagementFramework'] == 'getx') return true;
    return node.type == NodeType.notifier && node.name.endsWith('Controller');
  }

  String _presentationEntryLabel(List<GraphNode> members) {
    final presentations = members.where(_isPresentationNode);
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

  bool _isPresentationNode(GraphNode node) {
    if (node.type == NodeType.screen) return true;
    if (node.type != NodeType.widget) return false;
    return node.name.endsWith('Page') ||
        (node.file?.contains('/pages/') ?? false) ||
        (node.file?.endsWith('_page.dart') ?? false);
  }
}
