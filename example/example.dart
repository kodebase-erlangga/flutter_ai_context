// ignore_for_file: avoid_print

import 'package:flutter_ai_context/flutter_ai_context.dart';

/// Demonstrates building and serializing a small project knowledge graph.
void main() {
  final config = ProjectConfig(
    projectName: 'my_flutter_app',
    stateManagement: 'riverpod',
    routing: 'go_router',
  );

  print('Project: ${config.projectName}');
  print('State management: ${config.stateManagement}');

  final graph = ProjectGraph();
  graph.addNode(GraphNode(
    id: 'feature:auth',
    type: NodeType.feature,
    name: 'auth',
  ));
  graph.addNode(GraphNode(
    id: 'file:lib/features/auth/auth_screen.dart',
    type: NodeType.screen,
    name: 'AuthScreen',
    file: 'lib/features/auth/auth_screen.dart',
  ));
  graph.addEdge(GraphEdge(
    from: 'feature:auth',
    to: 'file:lib/features/auth/auth_screen.dart',
    type: EdgeType.contains,
  ));

  print('Graph nodes: ${graph.nodes.length}');
  print('Graph edges: ${graph.edges.length}');
  print('Screens: ${graph.nodesByType(NodeType.screen).map((n) => n.name).join(', ')}');
}
