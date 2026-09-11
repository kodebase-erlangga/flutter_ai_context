import 'package:flutter_ai_context/src/graph/edge.dart';
import 'package:flutter_ai_context/src/graph/node.dart';
import 'package:flutter_ai_context/src/graph/project_graph.dart';
import 'package:flutter_ai_context/src/graph/schema.dart';
import 'package:flutter_ai_context/src/inference/flow_inference.dart';
import 'package:test/test.dart';

void main() {
  final inference = FlowInference();

  test('detects GetX controller flow instead of Riverpod', () {
    final graph = ProjectGraph();
    final featureId = NodeId.forFeature('Auth');
    graph.addNode(
      GraphNode(id: featureId, type: NodeType.feature, name: 'Auth'),
    );
    graph.addNode(
      GraphNode(
        id: NodeId.forClass('lib/features/auth/pages/login_page.dart', 'LoginPage'),
        type: NodeType.screen,
        name: 'LoginPage',
        file: 'lib/features/auth/pages/login_page.dart',
        metadata: const {'superType': 'StatelessWidget'},
      ),
    );
    graph.addNode(
      GraphNode(
        id: NodeId.forClass(
          'lib/features/auth/controllers/auth_controller.dart',
          'AuthController',
        ),
        type: NodeType.notifier,
        name: 'AuthController',
        file: 'lib/features/auth/controllers/auth_controller.dart',
        metadata: const {'stateManagementFramework': 'getx'},
      ),
    );
    graph.addNode(
      GraphNode(
        id: NodeId.forClass(
          'lib/features/auth/data/auth_repository.dart',
          'AuthRepository',
        ),
        type: NodeType.repository,
        name: 'AuthRepository',
        file: 'lib/features/auth/data/auth_repository.dart',
      ),
    );
    for (final member in [
      'class:lib/features/auth/pages/login_page.dart:LoginPage',
      'class:lib/features/auth/controllers/auth_controller.dart:AuthController',
      'class:lib/features/auth/data/auth_repository.dart:AuthRepository',
    ]) {
      graph.addEdge(
        GraphEdge(from: featureId, to: member, type: EdgeType.contains),
      );
    }

    final flow = inference.inferFeatureFlow(graph, graph.findNode(featureId)!);
    expect(flow, 'Page -> GetX Controller -> Repository');
  });

  test('detects StatefulWidget page with repository flow', () {
    final graph = ProjectGraph();
    final featureId = NodeId.forFeature('Presensi');
    graph.addNode(
      GraphNode(id: featureId, type: NodeType.feature, name: 'Presensi'),
    );
    final screenId =
        NodeId.forClass('lib/features/presensi/pages/detail_page.dart', 'DetailPage');
    final repoId = NodeId.forClass(
      'lib/features/presensi/data/attendance_repository.dart',
      'AttendanceRepository',
    );
    graph.addNode(
      GraphNode(
        id: screenId,
        type: NodeType.screen,
        name: 'DetailPage',
        file: 'lib/features/presensi/pages/detail_page.dart',
        metadata: const {'superType': 'StatefulWidget'},
      ),
    );
    graph.addNode(
      GraphNode(
        id: repoId,
        type: NodeType.repository,
        name: 'AttendanceRepository',
        file: 'lib/features/presensi/data/attendance_repository.dart',
      ),
    );
    graph.addEdge(GraphEdge(from: featureId, to: screenId, type: EdgeType.contains));
    graph.addEdge(GraphEdge(from: featureId, to: repoId, type: EdgeType.contains));
    graph.addEdge(
      GraphEdge(from: screenId, to: repoId, type: EdgeType.reads),
    );

    final flow = inference.inferFeatureFlow(graph, graph.findNode(featureId)!);
    expect(flow, 'Page (StatefulWidget) -> Repository');
  });
}
