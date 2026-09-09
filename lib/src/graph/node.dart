import 'schema.dart';

/// Evidence supporting a classification or inference.
class Evidence {
  const Evidence({required this.description, this.weight = 1.0});

  final String description;
  final double weight;

  Map<String, dynamic> toJson() => {
        'description': description,
        'weight': weight,
      };

  factory Evidence.fromJson(Map<String, dynamic> json) => Evidence(
        description: json['description'] as String,
        weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
      );
}

/// A node in the project knowledge graph.
class GraphNode {
  GraphNode({
    required this.id,
    required this.type,
    required this.name,
    this.file,
    this.confidence = 1.0,
    this.evidence = const [],
    this.metadata = const {},
  });

  final String id;
  final NodeType type;
  final String name;
  final String? file;
  final double confidence;
  final List<Evidence> evidence;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.wireName,
        'name': name,
        if (file != null) 'file': file,
        'confidence': confidence,
        if (evidence.isNotEmpty)
          'evidence': evidence.map((e) => e.toJson()).toList(),
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  factory GraphNode.fromJson(Map<String, dynamic> json) => GraphNode(
        id: json['id'] as String,
        type: NodeTypeX.fromWire(json['type'] as String),
        name: json['name'] as String,
        file: json['file'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
        evidence: (json['evidence'] as List<dynamic>?)
                ?.map((e) => Evidence.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
      );
}

/// Stable node ID generation.
class NodeId {
  static String forClass(String file, String className) =>
      'class:$file:$className';

  static String forFile(String file) => 'file:$file';

  static String forFeature(String name) => 'feature:$name';

  static String forRoute(String path) => 'route:$path';
}
