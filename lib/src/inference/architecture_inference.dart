import '../graph/project_graph.dart';
import '../graph/schema.dart';
import 'confidence.dart';

/// Observed architecture flow pattern.
class ArchitectureFlow {
  ArchitectureFlow({
    required this.pattern,
    required this.percentage,
    required this.count,
    required this.evidence,
  });

  final String pattern;
  final double percentage;
  final int count;
  final List<String> evidence;
}

/// Architecture inference result.
class ArchitectureInference {
  ArchitectureInference({
    required this.dominantFlow,
    required this.flows,
    required this.confidence,
    required this.evidence,
  });

  final String? dominantFlow;
  final List<ArchitectureFlow> flows;
  final double confidence;
  final List<String> evidence;
}

/// Infers dominant architecture flows from the graph.
class ArchitectureInferenceEngine {
  ArchitectureInference infer(ProjectGraph graph) {
    final flowCounts = <String, int>{};
    final evidence = <String>[];

    final features = graph.nodesByType(NodeType.feature);
    for (final feature in features) {
      final members = graph
          .edgesFrom(feature.id)
          .where((e) => e.type == EdgeType.contains)
          .map((e) => graph.findNode(e.to))
          .whereType()
          .toList();

      final screen = members.where((m) => m.type == NodeType.screen).toList();
      final provider =
          members.where((m) => m.type == NodeType.provider).toList();
      final notifier =
          members.where((m) => m.type == NodeType.notifier).toList();
      final bloc = members
          .where((m) => m.type == NodeType.bloc || m.type == NodeType.cubit)
          .toList();
      final service = members.where((m) => m.type == NodeType.service).toList();
      final repository =
          members.where((m) => m.type == NodeType.repository).toList();

      String? flow;
      if (screen.isNotEmpty && notifier.isNotEmpty && repository.isNotEmpty) {
        flow = 'Screen -> Riverpod Notifier -> Repository';
      } else if (screen.isNotEmpty &&
          notifier.isNotEmpty &&
          service.isNotEmpty) {
        flow = 'Screen -> Riverpod Notifier -> Service';
      } else if (screen.isNotEmpty &&
          provider.isNotEmpty &&
          service.isNotEmpty) {
        flow = 'Screen -> Provider -> Service';
      } else if (screen.isNotEmpty &&
          bloc.isNotEmpty &&
          repository.isNotEmpty) {
        flow = 'Screen -> Bloc -> Repository';
      } else if (screen.isNotEmpty && bloc.isNotEmpty && service.isNotEmpty) {
        flow = 'Screen -> Bloc -> Service';
      } else if (screen.isNotEmpty &&
          provider.isNotEmpty &&
          repository.isNotEmpty) {
        flow = 'Screen -> Provider -> Repository -> Service';
      } else if (screen.isNotEmpty && service.isNotEmpty) {
        flow = 'Screen -> Service';
      } else if (screen.isNotEmpty && provider.isNotEmpty) {
        flow = 'Screen -> Provider';
      }

      if (flow != null) {
        flowCounts[flow] = (flowCounts[flow] ?? 0) + 1;
        evidence.add('${feature.name}: $flow');
      }
    }

    if (flowCounts.isEmpty) {
      return ArchitectureInference(
        dominantFlow: null,
        flows: [],
        confidence: 0,
        evidence: ['No complete feature flows detected'],
      );
    }

    final distribution = ConfidenceEngine.distribution(flowCounts);
    final flows = flowCounts.entries
        .map(
          (e) => ArchitectureFlow(
            pattern: e.key,
            count: e.value,
            percentage: distribution[e.key] ?? 0,
            evidence: evidence
                .where((ev) => ev.contains(e.key.split(' -> ').last))
                .toList(),
          ),
        )
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final dominant = flows.first;
    return ArchitectureInference(
      dominantFlow: dominant.pattern,
      flows: flows,
      confidence: dominant.percentage / 100,
      evidence: evidence,
    );
  }
}
