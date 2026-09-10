import '../graph/project_graph.dart';
import '../graph/schema.dart';

/// Suggests feature scopes when an exact match is not found.
class ScopeSuggester {
  List<String> suggest(
    ProjectGraph graph,
    String scope, {
    int limit = 5,
  }) {
    final normalized = scope.toLowerCase();
    final features =
        graph.nodesByType(NodeType.feature).map((node) => node.name).toList();

    final scored = <({String name, int score})>[];
    for (final feature in features) {
      final lower = feature.toLowerCase();
      var score = 0;
      if (lower == normalized) {
        score = 100;
      } else if (lower.startsWith(normalized) || normalized.startsWith(lower)) {
        score = 80;
      } else if (lower.contains(normalized) || normalized.contains(lower)) {
        score = 60;
      } else {
        score = _similarityScore(normalized, lower);
      }
      if (score > 0) scored.add((name: feature, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((entry) => entry.name).toList();
  }

  int _similarityScore(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final distance = _levenshtein(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    final similarity = ((maxLen - distance) / maxLen * 100).round();
    return similarity >= 55 ? similarity : 0;
  }

  int _levenshtein(String a, String b) {
    final rows = a.length + 1;
    final cols = b.length + 1;
    final matrix = List.generate(rows, (_) => List<int>.filled(cols, 0));

    for (var i = 0; i < rows; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j < cols; j++) {
      matrix[0][j] = j;
    }

    for (var i = 1; i < rows; i++) {
      for (var j = 1; j < cols; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((value, element) => value < element ? value : element);
      }
    }

    return matrix[a.length][b.length];
  }
}
