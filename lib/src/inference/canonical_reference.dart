import '../graph/project_graph.dart';
import '../graph/schema.dart';

/// Canonical reference feature for AI guidance.
class CanonicalReference {
  CanonicalReference({
    required this.featureName,
    required this.path,
    required this.score,
    required this.reasons,
  });

  final String featureName;
  final String path;
  final double score;
  final List<String> reasons;
}

/// Selects the best canonical feature reference.
class CanonicalReferenceDetector {
  CanonicalReference? detect(ProjectGraph graph, String? dominantFlow) {
    final features = graph.nodesByType(NodeType.feature);
    if (features.isEmpty) return null;

    CanonicalReference? best;
    for (final feature in features) {
      final members = graph
          .edgesFrom(feature.id)
          .where((e) => e.type == EdgeType.contains)
          .map((e) => graph.findNode(e.to))
          .whereType()
          .toList();

      var score = 0.0;
      final reasons = <String>[];

      final hasScreen = members.any((m) => m.type == NodeType.screen);
      final hasProvider = members.any((m) =>
          m.type == NodeType.provider ||
          m.type == NodeType.notifier ||
          m.type == NodeType.bloc);
      final hasService = members.any(
          (m) => m.type == NodeType.service || m.type == NodeType.repository);

      if (hasScreen) {
        score += 0.25;
        reasons.add('has screen layer');
      }
      if (hasProvider) {
        score += 0.25;
        reasons.add('uses primary state management');
      }
      if (hasService) {
        score += 0.25;
        reasons.add('uses expected service layer');
      }
      if (members.length >= 3) {
        score += 0.15;
        reasons.add('complete layer relationships');
      }
      if (dominantFlow != null) {
        score += 0.1;
        reasons.add('follows dominant project structure');
      }

      final screenFile = members
          .where((m) => m.type == NodeType.screen && m.file != null)
          .map((m) => m.file!)
          .firstOrNull;

      final candidate = CanonicalReference(
        featureName: feature.name,
        path: screenFile ?? 'lib/features/${feature.name.toLowerCase()}/',
        score: score,
        reasons: reasons,
      );

      if (best == null || candidate.score > best.score) {
        best = candidate;
      }
    }

    return best;
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
