import 'package:flutter_ai_context/src/graph/edge.dart';
import 'package:flutter_ai_context/src/graph/node.dart';
import 'package:flutter_ai_context/src/graph/project_graph.dart';
import 'package:flutter_ai_context/src/graph/schema.dart';
import 'package:flutter_ai_context/src/mcp/graph_query.dart';
import 'package:test/test.dart';

void main() {
  group('GraphQuery', () {
    final graph = ProjectGraph(
      nodes: [
        GraphNode(
          id: 'feature:Attendance',
          type: NodeType.feature,
          name: 'Attendance',
        ),
        GraphNode(
          id: 'class:lib/features/attendance/attendance_screen.dart#AttendanceScreen',
          type: NodeType.screen,
          name: 'AttendanceScreen',
          file: 'lib/features/attendance/attendance_screen.dart',
        ),
        GraphNode(
          id: 'class:lib/features/grade/grade_screen.dart#GradeScreen',
          type: NodeType.screen,
          name: 'GradeScreen',
          file: 'lib/features/grade/grade_screen.dart',
        ),
      ],
      edges: [
        GraphEdge(
          from:
              'class:lib/features/attendance/attendance_screen.dart#AttendanceScreen',
          to: 'feature:Attendance',
          type: EdgeType.belongsToFeature,
        ),
      ],
    );

    test('filters by node type', () {
      final result = const GraphQuery().query(graph, nodeType: 'screen');
      expect(result['total'], 2);
      final nodes = (result['nodes'] as List).cast<Map<String, Object?>>();
      expect(nodes.map((n) => n['name']), contains('AttendanceScreen'));
    });

    test('filters by feature', () {
      final result = const GraphQuery().query(graph, feature: 'Attendance');
      expect(result['total'], 2);
    });

    test('summarize counts nodes and edges by type', () {
      final summary = const GraphQuery().summarize(graph);
      expect(summary['nodeCount'], 3);
      expect(summary['edgeCount'], 1);
      expect(summary['nodesByType'], containsPair('screen', 2));
    });
  });
}
