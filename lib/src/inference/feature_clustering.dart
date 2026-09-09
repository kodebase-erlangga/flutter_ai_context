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
      final members = graph
          .edgesFrom(feature.id)
          .where((e) => e.type == EdgeType.contains)
          .map((e) => graph.findNode(e.to))
          .whereType()
          .map((n) => n.file ?? n.name)
          .cast<String>()
          .toList();
      return FeatureCluster(
        name: feature.name,
        members: members,
        confidence: feature.confidence,
      );
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }
}
