import 'schema.dart';

/// A directed edge in the project knowledge graph.
class GraphEdge {
  GraphEdge({
    required this.from,
    required this.to,
    required this.type,
    this.confidence = 1.0,
    this.evidence = const [],
  });

  final String from;
  final String to;
  final EdgeType type;
  final double confidence;
  final List<String> evidence;

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'type': type.wireName,
        'confidence': confidence,
        if (evidence.isNotEmpty) 'evidence': evidence,
      };

  factory GraphEdge.fromJson(Map<String, dynamic> json) => GraphEdge(
        from: json['from'] as String,
        to: json['to'] as String,
        type: EdgeTypeX.fromWire(json['type'] as String),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
        evidence: (json['evidence'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );
}
