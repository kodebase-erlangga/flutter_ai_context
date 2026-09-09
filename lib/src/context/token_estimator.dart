/// Estimates token count for context output.
class TokenEstimator {
  static int estimate(String text) {
    // Rough heuristic: ~4 characters per token for English/code mix.
    return (text.length / 4).ceil();
  }

  static int estimateLines(List<String> lines) {
    return estimate(lines.join('\n'));
  }
}
