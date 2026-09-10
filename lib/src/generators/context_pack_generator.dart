import '../context/relevance_ranker.dart';
import '../context/token_estimator.dart';
import '../graph/project_graph.dart';
import '../graph/schema.dart';
import '../shared/redaction.dart';
import 'markdown_header.dart';

/// Generates focused context packs.
class ContextPackGenerator {
  String generate({
    required String scope,
    required ProjectGraph graph,
    required List<RankedNode> ranked,
    String? observedFlow,
    int? maxTokens,
  }) {
    final selected = _selectForBudget(
      scope: scope,
      graph: graph,
      ranked: ranked,
      observedFlow: observedFlow,
      maxTokens: maxTokens,
    );

    return Redaction.sanitize(
      _render(
        scope: scope,
        ranked: selected,
        observedFlow: observedFlow,
      ),
    );
  }

  String _render({
    required String scope,
    required List<RankedNode> ranked,
    String? observedFlow,
  }) {
    final buffer = StringBuffer();
    buffer.write(MarkdownHeader.title('Context: $scope'));

    if (observedFlow != null) {
      buffer.writeln('## Observed Flow');
      buffer.writeln();
      buffer.writeln(observedFlow);
      buffer.writeln();
    }

    _writeGroup(buffer, 'Screens', ranked, _isScreen);
    _writeGroup(buffer, 'State Management', ranked, _isState);
    _writeGroup(buffer, 'Data Layer', ranked, _isData);
    _writeGroup(buffer, 'Routes', ranked, _isRoute);
    _writeGroup(buffer, 'Other', ranked, _isOther);

    buffer.writeln('## Related Nodes');
    buffer.writeln();
    for (final node in ranked) {
      buffer.writeln(
        '- **${node.name}** (${node.id}) — score ${node.score.toStringAsFixed(2)}',
      );
    }

    return buffer.toString();
  }

  List<RankedNode> _selectForBudget({
    required String scope,
    required ProjectGraph graph,
    required List<RankedNode> ranked,
    String? observedFlow,
    int? maxTokens,
  }) {
    if (maxTokens == null) return ranked;

    final selected = <RankedNode>[];
    for (final node in ranked) {
      final preview = _render(
        scope: scope,
        ranked: [...selected, node],
        observedFlow: observedFlow,
      );
      if (TokenEstimator.estimate(preview) > maxTokens) break;
      selected.add(node);
    }
    return selected;
  }

  void _writeGroup(
    StringBuffer buffer,
    String title,
    List<RankedNode> nodes,
    bool Function(NodeType?) predicate,
  ) {
    final group = nodes.where((node) => predicate(node.type)).toList();
    if (group.isEmpty) return;

    buffer.writeln('## $title');
    buffer.writeln();
    for (final node in group) {
      if (node.file != null) {
        buffer.writeln(
          '- `${node.file}` — ${node.reason} (${node.score.toStringAsFixed(2)})',
        );
      }
    }
    buffer.writeln();
  }

  bool _isScreen(NodeType? type) => type == NodeType.screen;

  bool _isState(NodeType? type) {
    return type == NodeType.provider ||
        type == NodeType.bloc ||
        type == NodeType.cubit ||
        type == NodeType.notifier;
  }

  bool _isData(NodeType? type) {
    return type == NodeType.service ||
        type == NodeType.repository ||
        type == NodeType.apiClient ||
        type == NodeType.model ||
        type == NodeType.entity;
  }

  bool _isRoute(NodeType? type) => type == NodeType.route;

  bool _isOther(NodeType? type) {
    return type == null ||
        (!_isScreen(type) &&
            !_isState(type) &&
            !_isData(type) &&
            !_isRoute(type));
  }

  int estimateTokens(String content) => TokenEstimator.estimate(content);
}
