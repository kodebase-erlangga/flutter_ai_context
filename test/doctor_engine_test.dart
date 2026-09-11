import 'package:flutter_ai_context/src/config/models/project_config.dart';
import 'package:flutter_ai_context/src/graph/edge.dart';
import 'package:flutter_ai_context/src/graph/node.dart';
import 'package:flutter_ai_context/src/graph/project_graph.dart';
import 'package:flutter_ai_context/src/graph/schema.dart';
import 'package:flutter_ai_context/src/inference/architecture_inference.dart';
import 'package:flutter_ai_context/src/inference/state_management_detector.dart';
import 'package:flutter_ai_context/src/rules/doctor_engine.dart';
import 'package:flutter_ai_context/src/rules/findings.dart';
import 'package:test/test.dart';

DoctorReport _analyze({
  required ProjectGraph graph,
  List<String> dioUsageInUi = const [],
}) {
  return DoctorEngine().analyze(
    config: ProjectConfig(projectName: 'demo'),
    graph: graph,
    stateManagement: StateManagementResult(
      primary: 'GetX',
      distribution: const {'getx': 1.0},
      confidence: 0.9,
      evidence: const ['GetX detected'],
    ),
    architecture: ArchitectureInference(
      dominantFlow: 'Page -> GetX Controller -> Repository',
      flows: const [],
      confidence: 0.9,
      evidence: const ['feature flow'],
    ),
    dioUsageInUi: dioUsageInUi,
  );
}

void main() {
  test('info findings do not reduce feature mapping score', () {
    final graph = ProjectGraph();
    graph.addNode(
      GraphNode(
        id: NodeId.forFeature('Empty'),
        type: NodeType.feature,
        name: 'Empty',
      ),
    );
    graph.addNode(
      GraphNode(
        id: NodeId.forClass('lib/empty/empty_service.dart', 'EmptyService'),
        type: NodeType.service,
        name: 'EmptyService',
        file: 'lib/empty/empty_service.dart',
      ),
    );
    graph.addEdge(
      GraphEdge(
        from: NodeId.forFeature('Empty'),
        to: NodeId.forClass('lib/empty/empty_service.dart', 'EmptyService'),
        type: EdgeType.contains,
      ),
    );

    final report = _analyze(graph: graph);
    final missingScreen = report.findings
        .where((finding) => finding.rule == 'feature.missing_screen')
        .toList();

    expect(missingScreen, hasLength(1));
    expect(missingScreen.single.severity, FindingSeverity.info);
    expect(report.dimensions['Feature Mapping'], 70);
  });

  test('warning findings still reduce architecture score', () {
    final graph = ProjectGraph();
    graph.addNode(
      GraphNode(
        id: NodeId.forClass('lib/ui/bad_screen.dart', 'BadScreen'),
        type: NodeType.screen,
        name: 'BadScreen',
        file: 'lib/ui/bad_screen.dart',
      ),
    );

    final clean = _analyze(graph: graph);
    final withWarning = _analyze(
      graph: graph,
      dioUsageInUi: const ['class:lib/ui/bad_screen.dart:BadScreen'],
    );

    expect(
      withWarning.dimensions['Architecture'],
      lessThan(clean.dimensions['Architecture']!),
    );
  });
}
