import 'package:flutter_ai_context/src/graph/node.dart';
import 'package:flutter_ai_context/src/inference/confidence.dart';
import 'package:test/test.dart';

void main() {
  test('ConfidenceEngine distribution is deterministic', () {
    final distribution = ConfidenceEngine.distribution({
      'Provider': 17,
      'Bloc': 3,
    });

    expect(distribution['Provider'], closeTo(85, 0.1));
    expect(distribution['Bloc'], closeTo(15, 0.1));
  });

  test('ConfidenceEngine fromEvidence increases with weight', () {
    final low = ConfidenceEngine.fromEvidence([
      const Evidence(description: 'a'),
    ]);
    final high = ConfidenceEngine.fromEvidence([
      const Evidence(description: 'a', weight: 3),
      const Evidence(description: 'b', weight: 3),
    ]);
    expect(high, greaterThan(low));
  });
}
