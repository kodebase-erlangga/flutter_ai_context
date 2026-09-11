import '../graph/project_graph.dart';
import '../graph/schema.dart';
import 'confidence.dart';
import 'flow_inference.dart';

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
  ArchitectureInferenceEngine({FlowInference? flowInference})
      : _flowInference = flowInference ?? FlowInference();

  final FlowInference _flowInference;

  ArchitectureInference infer(ProjectGraph graph) {
    final flowCounts = <String, int>{};
    final evidence = <String>[];

    for (final feature in graph.nodesByType(NodeType.feature)) {
      final flow = _flowInference.inferFeatureFlow(graph, feature);
      if (flow == null) continue;
      flowCounts[flow] = (flowCounts[flow] ?? 0) + 1;
      evidence.add('${feature.name}: $flow');
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
            evidence:
                evidence.where((ev) => ev.contains(': ${e.key}')).toList(),
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
