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
  });

  final String id;
  final String name;
  final String? file;
  final double score;
  final String reason;
}

/// Ranks nodes by relevance to a scope.
class RelevanceRanker {
  List<RankedNode> rank(ProjectGraph graph, String scope) {
    final normalizedScope = scope.toLowerCase();
    final ranked = <RankedNode>[];

    GraphNode? featureNode;
    for (final node in graph.nodesByType(NodeType.feature)) {
      if (node.name.toLowerCase() == normalizedScope) {
        featureNode = node;
        break;
      }
    }

    if (featureNode != null) {
      for (final edge in graph.edgesFrom(featureNode.id)) {
        final node = graph.findNode(edge.to);
        if (node == null) continue;
        ranked.add(
          RankedNode(
            id: node.id,
            name: node.name,
            file: node.file,
            score: 1.0,
            reason: 'direct feature membership',
          ),
        );
      }

      _addSharedDependencies(graph, ranked);
    } else {
      for (final node in graph.nodes) {
        if (node.name.toLowerCase().contains(normalizedScope) ||
            (node.file?.toLowerCase().contains(normalizedScope) ?? false)) {
          ranked.add(
            RankedNode(
              id: node.id,
              name: node.name,
              file: node.file,
              score: 0.8,
              reason: 'scope name match',
            ),
          );
        }
      }
    }

    ranked.sort((a, b) => b.score.compareTo(a.score));
    return ranked;
  }

  void _addSharedDependencies(ProjectGraph graph, List<RankedNode> ranked) {
    final existingIds = ranked.map((r) => r.id).toSet();
    for (final node in ranked.toList()) {
      for (final edge in graph.edgesFrom(node.id)) {
        final target = graph.findNode(edge.to);
        if (target == null || existingIds.contains(target.id)) continue;
        if (target.type == NodeType.apiClient ||
            target.type == NodeType.service) {
          ranked.add(
            RankedNode(
              id: target.id,
              name: target.name,
              file: target.file,
              score: 0.6,
              reason: 'shared dependency',
            ),
          );
          existingIds.add(target.id);
        }
      }
    }
  }
}
