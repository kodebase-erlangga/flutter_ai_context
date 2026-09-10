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
  static const _relationshipEdges = {
    EdgeType.contains,
    EdgeType.calls,
    EdgeType.dependsOn,
    EdgeType.watches,
    EdgeType.reads,
    EdgeType.usesService,
    EdgeType.belongsToFeature,
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
      _walkFromNode(
        graph: graph,
        startId: featureNode.id,
        scores: scores,
        baseScore: 1.0,
        reason: 'feature root',
        maxDepth: 4,
      );
      for (final edge in graph.edgesFrom(featureNode.id)) {
        if (edge.type != EdgeType.contains) continue;
        _walkFromNode(
          graph: graph,
          startId: edge.to,
          scores: scores,
          baseScore: 1.0,
          reason: 'direct feature membership',
          maxDepth: 3,
        );
      }

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
      );
    }

    return RankResult(nodes: _sortedUnique(scores));
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
      if (existing == null || node.score > existing.score) {
        byFile[node.file!] = node;
      }
    }

    final merged = [...byFile.values, ...withoutFile];
    merged.sort((a, b) => b.score.compareTo(a.score));
    return merged;
  }

  void _walkFromNode({
    required ProjectGraph graph,
    required String startId,
    required Map<String, RankedNode> scores,
    required double baseScore,
    required String reason,
    required int maxDepth,
  }) {
    final queue = <({String id, int depth})>[(id: startId, depth: 0)];
    final visited = <String>{};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (!visited.add(current.id)) continue;
      if (current.depth > maxDepth) continue;

      final node = graph.findNode(current.id);
      if (node == null) continue;

      final roleBoost = _roleBoost(node.type);
      final hopPenalty = current.depth * 0.12;
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

      for (final edge in graph.edgesFrom(node.id)) {
        if (!_relationshipEdges.contains(edge.type)) continue;
        queue.add((id: edge.to, depth: current.depth + 1));
      }
      for (final edge in graph.edgesTo(node.id)) {
        if (!_relationshipEdges.contains(edge.type)) continue;
        queue.add((id: edge.from, depth: current.depth + 1));
      }
    }
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
        .whereType()
        .toList();

    final hasScreen = members.any((m) => m.type == NodeType.screen);
    final hasProvider = members.any((m) => m.type == NodeType.provider);
    final hasNotifier = members.any((m) => m.type == NodeType.notifier);
    final hasBloc = members.any(
      (m) => m.type == NodeType.bloc || m.type == NodeType.cubit,
    );
    final hasService = members.any(
      (m) =>
          m.type == NodeType.service ||
          m.type == NodeType.repository ||
          m.type == NodeType.apiClient,
    );

    if (hasScreen && hasNotifier && hasService) {
      return 'Screen -> Riverpod Notifier -> Repository';
    }
    if (hasScreen && hasBloc && hasService) {
      return 'Screen -> Bloc -> Repository';
    }
    if (hasScreen && hasProvider && hasService) {
      return 'Screen -> Provider -> Service';
    }
    if (hasScreen && hasProvider) return 'Screen -> Provider';
    if (hasScreen && hasBloc) return 'Screen -> Bloc';
    return null;
  }
}
