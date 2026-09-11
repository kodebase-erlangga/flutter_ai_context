import 'dart:math';

import '../graph/node.dart';
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
    this.graphCounts = const {},
    this.signalCounts = const {},
    this.diLayerFramework,
  });

  final String? primary;
  final String? secondary;
  final Map<String, double> distribution;
  final double confidence;
  final List<String> evidence;

  /// Architectural node counts (controllers, providers, blocs, etc.).
  final Map<String, int> graphCounts;

  /// Lightweight import/usage signal counts (Consumer, context.read, etc.).
  final Map<String, int> signalCounts;

  /// Framework seen mainly as usage signals (e.g. Provider for widget DI).
  final String? diLayerFramework;

  /// True when architecture and DI/widget layers use different frameworks.
  bool get isHybrid {
    if (primary == null) return false;
    if (secondary != null && (distribution[secondary] ?? 0) >= 15) {
      return true;
    }
    return diLayerFramework != null && diLayerFramework != primary;
  }

  /// Short note for AGENTS.md when [isHybrid] is true.
  String? get hybridNote {
    if (!isHybrid || primary == null) return null;
    final di = diLayerFramework ?? secondary;
    if (di != null && di != primary) {
      return '$primary drives feature architecture; $di also appears for DI/widgets.';
    }
    if (secondary != null && secondary != primary) {
      return '$primary drives feature architecture; $secondary also appears for DI/widgets.';
    }
    return null;
  }
}

/// Detects state management patterns from graph nodes first, then signals.
class StateManagementDetector {
  static const _graphWeight = 5;
  static const _signalWeight = 1;
  static const _diSignalThreshold = 15;

  StateManagementResult detect({
    required ProjectGraph graph,
    required Map<String, int> signals,
    List<String> dependencyCandidates = const [],
  }) {
    final graphCounts = _countGraphNodes(graph);
    final signalCounts = _normalizeSignals(signals);
    final maxGraphCount = graphCounts.values.fold(0, max);

    final weighted = <String, int>{};
    for (final framework in const [
      'GetX',
      'Provider',
      'Bloc',
      'Riverpod',
    ]) {
      final graph = graphCounts[framework]!;
      final effectiveSignals = _effectiveSignalCount(
        graphCount: graph,
        signalCount: signalCounts[framework]!,
        maxGraphCount: maxGraphCount,
      );
      final total = graph * _graphWeight + effectiveSignals * _signalWeight;
      if (total > 0) {
        weighted[framework] = total;
      }
    }

    final evidence = <String>[];
    for (final entry in graphCounts.entries) {
      if (entry.value > 0) {
        evidence.add('${entry.value} ${entry.key} architectural nodes');
      }
    }
    for (final entry in signalCounts.entries) {
      if (entry.value > 0) {
        evidence.add('${entry.value} ${entry.key} usage signals');
      }
    }
    for (final candidate in dependencyCandidates) {
      evidence.add('$candidate dependency installed');
    }

    if (weighted.isEmpty) {
      return StateManagementResult(
        primary: null,
        distribution: {},
        confidence: 0,
        evidence: ['No state management patterns detected'],
        graphCounts: graphCounts,
        signalCounts: signalCounts,
      );
    }

    final graphPrimary = _primaryFromGraph(graphCounts);
    final diLayer = _diLayerFramework(
      graphPrimary: graphPrimary,
      graphCounts: graphCounts,
      signalCounts: signalCounts,
    );

    final distribution = graphPrimary != null
        ? ConfidenceEngine.distribution(_nonZeroCounts(graphCounts))
        : ConfidenceEngine.distribution(weighted);

    final primary = graphPrimary ?? _topKey(weighted);
    final secondary = _secondaryFramework(
      primary: primary,
      graphCounts: graphCounts,
      weighted: weighted,
      diLayer: diLayer,
    );

    final primaryPct = distribution[primary] ?? 0;

    return StateManagementResult(
      primary: primary,
      secondary: secondary,
      distribution: distribution,
      confidence: primaryPct / 100,
      evidence: evidence,
      graphCounts: graphCounts,
      signalCounts: signalCounts,
      diLayerFramework: diLayer,
    );
  }

  String? _primaryFromGraph(Map<String, int> graphCounts) {
    final active = graphCounts.entries.where((e) => e.value > 0).toList();
    if (active.isEmpty) return null;
    active.sort((a, b) => b.value.compareTo(a.value));
    return active.first.key;
  }

  String? _diLayerFramework({
    required String? graphPrimary,
    required Map<String, int> graphCounts,
    required Map<String, int> signalCounts,
  }) {
    if (graphPrimary == null) return null;

    final candidates = signalCounts.entries
        .where(
          (e) =>
              e.key != graphPrimary &&
              e.value >= _diSignalThreshold &&
              graphCounts[e.key]! == 0,
        )
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return candidates.isEmpty ? null : candidates.first.key;
  }

  String? _secondaryFramework({
    required String primary,
    required Map<String, int> graphCounts,
    required Map<String, int> weighted,
    required String? diLayer,
  }) {
    if (diLayer != null) return diLayer;

    final graphSecondaries = graphCounts.entries
        .where((e) => e.key != primary && e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (graphSecondaries.isNotEmpty) return graphSecondaries.first.key;

    final weightedSecondaries = weighted.entries
        .where((e) => e.key != primary)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return weightedSecondaries.isEmpty ? null : weightedSecondaries.first.key;
  }

  Map<String, int> _nonZeroCounts(Map<String, int> counts) {
    return Map.fromEntries(counts.entries.where((e) => e.value > 0));
  }

  String _topKey(Map<String, int> counts) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  Map<String, int> _countGraphNodes(ProjectGraph graph) {
    final counts = {
      'GetX': 0,
      'Provider': 0,
      'Bloc': 0,
      'Riverpod': 0,
    };

    for (final node in graph.nodes) {
      final framework = node.metadata['stateManagementFramework'] as String?;
      switch (node.type) {
        case NodeType.bloc:
        case NodeType.cubit:
          counts['Bloc'] = counts['Bloc']! + 1;
        case NodeType.provider:
          if (framework == 'getx') {
            counts['GetX'] = counts['GetX']! + 1;
          } else {
            counts['Provider'] = counts['Provider']! + 1;
          }
        case NodeType.notifier:
          if (framework == 'getx' || _looksLikeGetxController(node)) {
            counts['GetX'] = counts['GetX']! + 1;
          } else if (framework == 'riverpod') {
            counts['Riverpod'] = counts['Riverpod']! + 1;
          }
        default:
          break;
      }
    }

    return counts;
  }

  bool _looksLikeGetxController(GraphNode node) {
    final file = node.file ?? '';
    final inControllersPath = file.contains('/controllers/') ||
        file.contains(r'\controllers\');
    final controllerName = node.name.endsWith('Controller');
    return inControllersPath && controllerName;
  }

  Map<String, int> _normalizeSignals(Map<String, int> signals) {
    return {
      'GetX': signals['getx'] ?? 0,
      'Provider': signals['provider'] ?? 0,
      'Bloc': signals['bloc'] ?? 0,
      'Riverpod': signals['riverpod'] ?? 0,
    };
  }

  /// Caps usage signals so graph architecture drives primary SM.
  int _effectiveSignalCount({
    required int graphCount,
    required int signalCount,
    required int maxGraphCount,
  }) {
    if (graphCount > 0) {
      return min(signalCount, graphCount + 5);
    }
    if (maxGraphCount > 0) {
      // Signal-only usage (e.g. Provider Consumer in a GetX app).
      return min(signalCount, max(5, maxGraphCount + 3));
    }
    return signalCount;
  }
}
