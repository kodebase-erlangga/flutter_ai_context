import '../graph/project_graph.dart';
import '../graph/schema.dart';
import 'confidence.dart';

/// State management detection result.
class StateManagementResult {
  StateManagementResult({
    required this.primary,
    required this.distribution,
    required this.confidence,
    required this.evidence,
    this.secondary,
  });

  final String? primary;
  final String? secondary;
  final Map<String, double> distribution;
  final double confidence;
  final List<String> evidence;
}

/// Detects state management patterns from graph and signals.
class StateManagementDetector {
  StateManagementResult detect({
    required ProjectGraph graph,
    required Map<String, int> signals,
    List<String> dependencyCandidates = const [],
  }) {
    final counts = <String, int>{};

    counts['Provider'] = graph.nodesByType(NodeType.provider).length +
        (signals['provider'] ?? 0);
    counts['Bloc'] = graph.nodesByType(NodeType.bloc).length +
        graph.nodesByType(NodeType.cubit).length +
        (signals['bloc'] ?? 0);
    counts['Riverpod'] = (signals['riverpod'] ?? 0);
    counts['GetX'] = (signals['getx'] ?? 0);

    for (final node in graph.nodes) {
      final framework = node.metadata['stateManagementFramework'] as String?;
      switch (framework) {
        case 'riverpod':
          counts['Riverpod'] = (counts['Riverpod'] ?? 0) + 2;
        case 'getx':
          counts['GetX'] = (counts['GetX'] ?? 0) + 2;
      }
      if (node.type == NodeType.notifier &&
          framework != 'getx' &&
          framework != 'riverpod') {
        counts['Riverpod'] = (counts['Riverpod'] ?? 0) + 1;
      }
    }

    counts.removeWhere((_, v) => v == 0);

    final evidence = <String>[];
    for (final entry in counts.entries) {
      evidence.add('${entry.value} ${entry.key} indicators');
    }
    for (final candidate in dependencyCandidates) {
      evidence.add('$candidate dependency installed');
    }

    if (counts.isEmpty) {
      return StateManagementResult(
        primary: null,
        distribution: {},
        confidence: 0,
        evidence: ['No state management patterns detected'],
      );
    }

    final distribution = ConfidenceEngine.distribution(counts);
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final primary = sorted.first.key;
    final secondary = sorted.length > 1 ? sorted[1].key : null;
    final primaryPct = distribution[primary] ?? 0;

    return StateManagementResult(
      primary: primary,
      secondary: secondary,
      distribution: distribution,
      confidence: primaryPct / 100,
      evidence: evidence,
    );
  }
}
