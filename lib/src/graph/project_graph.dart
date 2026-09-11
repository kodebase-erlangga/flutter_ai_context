import 'node.dart';
import 'edge.dart';
import 'schema.dart';

/// In-memory project knowledge graph.
///
/// Nodes represent files, classes, features, routes, and other
/// architectural elements. Edges capture imports, dependencies,
/// navigation, and other relationships inferred during scanning.
class ProjectGraph {
  /// Creates an empty or pre-populated graph.
  ProjectGraph({
    this.schemaVersion = graphSchemaVersion,
    List<GraphNode>? nodes,
    List<GraphEdge>? edges,
  })  : nodes = nodes ?? [],
        edges = edges ?? [];

  /// Schema version for cache compatibility ([graphSchemaVersion]).
  int schemaVersion;

  /// All nodes in the graph.
  final List<GraphNode> nodes;

  /// All directed edges between nodes.
  final List<GraphEdge> edges;

  /// Returns the node with [id], or `null` if not found.
  GraphNode? findNode(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  /// Returns all nodes of the given [type].
  List<GraphNode> nodesByType(NodeType type) =>
      nodes.where((n) => n.type == type).toList();

  /// Returns all nodes originating from [file].
  List<GraphNode> nodesByFile(String file) =>
      nodes.where((n) => n.file == file).toList();

  /// Returns outgoing edges from [nodeId].
  List<GraphEdge> edgesFrom(String nodeId) =>
      edges.where((e) => e.from == nodeId).toList();

  /// Returns incoming edges to [nodeId].
  List<GraphEdge> edgesTo(String nodeId) =>
      edges.where((e) => e.to == nodeId).toList();

  /// Adds or replaces a node (matched by [GraphNode.id]).
  void addNode(GraphNode node) {
    final existing = findNode(node.id);
    if (existing != null) {
      nodes.remove(existing);
    }
    nodes.add(node);
  }

  /// Appends an edge to the graph.
  void addEdge(GraphEdge edge) {
    edges.add(edge);
  }

  /// Serializes the graph to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
      };

  /// Deserializes a graph from a JSON-compatible map.
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
