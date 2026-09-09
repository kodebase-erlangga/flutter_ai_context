import 'node.dart';
import 'edge.dart';
import 'schema.dart';

/// In-memory project knowledge graph.
class ProjectGraph {
  ProjectGraph({
    this.schemaVersion = graphSchemaVersion,
    List<GraphNode>? nodes,
    List<GraphEdge>? edges,
  })  : nodes = nodes ?? [],
        edges = edges ?? [];

  int schemaVersion;
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  GraphNode? findNode(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  List<GraphNode> nodesByType(NodeType type) =>
      nodes.where((n) => n.type == type).toList();

  List<GraphNode> nodesByFile(String file) =>
      nodes.where((n) => n.file == file).toList();

  List<GraphEdge> edgesFrom(String nodeId) =>
      edges.where((e) => e.from == nodeId).toList();

  List<GraphEdge> edgesTo(String nodeId) =>
      edges.where((e) => e.to == nodeId).toList();

  void addNode(GraphNode node) {
    final existing = findNode(node.id);
    if (existing != null) {
      nodes.remove(existing);
    }
    nodes.add(node);
  }

  void addEdge(GraphEdge edge) {
    edges.add(edge);
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
      };

  factory ProjectGraph.fromJson(Map<String, dynamic> json) => ProjectGraph(
        schemaVersion: json['schemaVersion'] as int? ?? graphSchemaVersion,
        nodes: (json['nodes'] as List<dynamic>?)
                ?.map((n) => GraphNode.fromJson(n as Map<String, dynamic>))
                .toList() ??
            [],
        edges: (json['edges'] as List<dynamic>?)
                ?.map((e) => GraphEdge.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
