import '../graph/node.dart';

/// Deterministic confidence scoring from evidence.
class ConfidenceEngine {
  /// Computes confidence from weighted evidence (0.0 - 1.0).
  static double fromEvidence(List<Evidence> evidence, {double base = 0.5}) {
    if (evidence.isEmpty) return base;
    var score = base;
    for (final e in evidence) {
      score += e.weight * 0.1;
    }
    return score.clamp(0.0, 1.0);
  }

  /// Percentage distribution from counts.
  static Map<String, double> distribution(Map<String, int> counts) {
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return {};
    return counts.map((k, v) => MapEntry(k, (v / total) * 100));
  }

  static int toScore(double confidence) => (confidence * 100).round();
}
