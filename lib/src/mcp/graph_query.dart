import '../graph/node.dart';
import '../graph/project_graph.dart';
import '../graph/schema.dart';

/// Filters and summarizes nodes in the project knowledge graph.
class GraphQuery {
  const GraphQuery();

  static const defaultLimit = 50;
  static const maxLimit = 200;

  Map<String, Object?> query(
    ProjectGraph graph, {
    String? nodeType,
    String? feature,
    String? nameContains,
    int limit = defaultLimit,
    int offset = 0,
  }) {
    final effectiveLimit = limit.clamp(1, maxLimit);
    final parsedType = _parseNodeType(nodeType);
    final featureId = _resolveFeatureId(graph, feature);

    final matched = <GraphNode>[];
    for (final node in graph.nodes) {
      if (parsedType != null && node.type != parsedType) continue;
      if (featureId != null && !_belongsToFeature(graph, node, featureId)) {
        continue;
      }
      if (nameContains != null &&
          nameContains.isNotEmpty &&
          !node.name.toLowerCase().contains(nameContains.toLowerCase())) {
        continue;
      }
      matched.add(node);
    }

    matched.sort((a, b) => a.name.compareTo(b.name));
    final total = matched.length;
    final page = matched.skip(offset).take(effectiveLimit).toList();

    return {
      'total': total,
      'offset': offset,
      'limit': effectiveLimit,
      'nodes': page.map(_nodeSummary).toList(),
    };
  }

  Map<String, Object?> summarize(ProjectGraph graph, {int? fileBytes}) {
    final nodesByType = <String, int>{};
    for (final node in graph.nodes) {
      final key = node.type.wireName;
      nodesByType[key] = (nodesByType[key] ?? 0) + 1;
    }

    final edgesByType = <String, int>{};
    for (final edge in graph.edges) {
      final key = edge.type.wireName;
      edgesByType[key] = (edgesByType[key] ?? 0) + 1;
    }

    return {
      'schemaVersion': graph.schemaVersion,
      'nodeCount': graph.nodes.length,
      'edgeCount': graph.edges.length,
      if (fileBytes != null) 'fileBytes': fileBytes,
      'nodesByType': nodesByType,
      'edgesByType': edgesByType,
      'hint': 'Use tool `query_graph` for filtered node listings.',
    };
  }

  NodeType? _parseNodeType(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final type in NodeType.values) {
      if (type.name.toLowerCase() == normalized ||
          type.wireName.toLowerCase() == normalized) {
        return type;
      }
    }
    throw ArgumentError('Unknown node type: $value');
  }

  String? _resolveFeatureId(ProjectGraph graph, String? feature) {
    if (feature == null || feature.isEmpty) return null;
    final match = graph.nodesByType(NodeType.feature).where(
      (node) => node.name.toLowerCase() == feature.toLowerCase(),
    );
    if (match.isEmpty) {
      throw ArgumentError('Unknown feature: $feature');
    }
    return match.first.id;
  }

  bool _belongsToFeature(
    ProjectGraph graph,
    GraphNode node,
    String featureId,
  ) {
    if (node.id == featureId) return true;

    for (final edge in graph.edges) {
      if (edge.type == EdgeType.belongsToFeature &&
          edge.to == featureId &&
          edge.from == node.id) {
        return true;
      }
    }

    final file = node.file?.toLowerCase();
    if (file != null) {
      final featureName = graph.findNode(featureId)?.name.toLowerCase();
      if (featureName != null && file.contains('/features/$featureName/')) {
        return true;
      }
    }

    return false;
  }

  Map<String, Object?> _nodeSummary(GraphNode node) {
    return {
      'id': node.id,
      'type': node.type.wireName,
      'name': node.name,
      if (node.file != null) 'file': node.file,
      if (node.confidence != 1.0) 'confidence': node.confidence,
    };
  }
}
