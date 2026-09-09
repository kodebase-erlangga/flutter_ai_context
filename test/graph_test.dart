import 'dart:convert';

import 'package:flutter_ai_context/src/graph/edge.dart';
import 'package:flutter_ai_context/src/graph/node.dart';
import 'package:flutter_ai_context/src/graph/project_graph.dart';
import 'package:flutter_ai_context/src/graph/schema.dart';
import 'package:test/test.dart';

void main() {
  test('ProjectGraph serializes and deserializes', () {
    final graph = ProjectGraph(
      nodes: [
        GraphNode(
          id: NodeId.forClass('lib/a.dart', 'Foo'),
          type: NodeType.screen,
          name: 'Foo',
          file: 'lib/a.dart',
          confidence: 0.95,
        ),
      ],
      edges: [
        GraphEdge(
          from: NodeId.forClass('lib/a.dart', 'Foo'),
          to: NodeId.forClass('lib/b.dart', 'Bar'),
          type: EdgeType.calls,
        ),
      ],
    );

    final restored = ProjectGraph.fromJson(
      jsonDecode(jsonEncode(graph.toJson())) as Map<String, dynamic>,
    );

    expect(restored.nodes.length, 1);
    expect(restored.edges.length, 1);
    expect(restored.nodes.first.type, NodeType.screen);
  });
}
