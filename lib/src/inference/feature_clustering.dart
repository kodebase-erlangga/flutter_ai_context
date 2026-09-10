import '../graph/project_graph.dart';
import '../graph/schema.dart';

/// Feature cluster with members and confidence.
class FeatureCluster {
  FeatureCluster({
    required this.name,
    required this.members,
    required this.confidence,
  });

  final String name;
  final List<String> members;
  final double confidence;
}

/// Clusters files/classes into features.
class FeatureClustering {
  List<FeatureCluster> cluster(ProjectGraph graph) {
    return graph.nodesByType(NodeType.feature).map((feature) {
      final seen = <String>{};
      final members = <String>[];
      for (final edge in graph.edgesFrom(feature.id)) {
        if (edge.type != EdgeType.contains) continue;
        final node = graph.findNode(edge.to);
        if (node == null) continue;
        final member = node.file ?? node.name;
        if (seen.add(member)) members.add(member);
      }
      return FeatureCluster(
        name: feature.name,
        members: members,
        confidence: feature.confidence,
      );
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }
}
