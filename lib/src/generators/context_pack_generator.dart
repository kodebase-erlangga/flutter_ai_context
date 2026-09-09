import '../context/relevance_ranker.dart';
import '../context/token_estimator.dart';
import '../graph/project_graph.dart';
import '../shared/redaction.dart';
import 'markdown_header.dart';

/// Generates focused context packs.
class ContextPackGenerator {
  String generate({
    required String scope,
    required ProjectGraph graph,
    required List<RankedNode> ranked,
  }) {
    final buffer = StringBuffer();
    buffer.write(MarkdownHeader.title('Context: $scope'));
    buffer.writeln('## Relevant Files');
    buffer.writeln();
    for (final node in ranked) {
      if (node.file != null) {
        buffer.writeln('- `${node.file}` — ${node.reason}');
      }
    }
    buffer.writeln();
    buffer.writeln('## Related Nodes');
    buffer.writeln();
    for (final node in ranked) {
      buffer.writeln('- **${node.name}** (${node.id})');
    }
    return Redaction.sanitize(buffer.toString());
  }

  int estimateTokens(String content) => TokenEstimator.estimate(content);
}
