import '../context/class_signature.dart';
import '../context/relevance_ranker.dart';
import '../context/token_estimator.dart';
import '../graph/project_graph.dart';
import '../graph/schema.dart';
import '../shared/redaction.dart';
import 'markdown_header.dart';

/// Generated context pack with the nodes that fit the token budget.
class ContextPackResult {
  ContextPackResult({
    required this.content,
    required this.selectedNodes,
  });

  final String content;
  final List<RankedNode> selectedNodes;
}

/// Generates focused context packs.
class ContextPackGenerator {
  ContextPackGenerator({ClassSignatureFormatter? signatureFormatter})
      : _signatureFormatter = signatureFormatter ?? ClassSignatureFormatter();

  final ClassSignatureFormatter _signatureFormatter;

  ContextPackResult build({
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

    return ContextPackResult(
      content: Redaction.sanitize(
        _render(
          scope: scope,
          graph: graph,
          ranked: selected,
          observedFlow: observedFlow,
        ),
      ),
      selectedNodes: selected,
    );
  }

  String generate({
    required String scope,
    required ProjectGraph graph,
    required List<RankedNode> ranked,
    String? observedFlow,
    int? maxTokens,
  }) {
    return build(
      scope: scope,
      graph: graph,
      ranked: ranked,
      observedFlow: observedFlow,
      maxTokens: maxTokens,
    ).content;
  }

  String _render({
    required String scope,
    required ProjectGraph graph,
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
      _writeAgentGuide(buffer, scope, observedFlow, ranked);
    }

    final entryPoints = ranked
        .where((node) => _isScreen(node.type) && node.file != null)
        .map((node) => node.file!)
        .toList();
    if (entryPoints.isNotEmpty) {
      buffer.writeln('## Entry Points');
      buffer.writeln();
      for (final file in entryPoints) {
        buffer.writeln('- `$file`');
      }
      buffer.writeln();
    }

    final groupedIds = <String>{};
    _writeGroup(
      buffer,
      graph,
      'Screens',
      ranked,
      _isScreen,
      groupedIds,
    );
    _writeGroup(
      buffer,
      graph,
      'State Management',
      ranked,
      _isState,
      groupedIds,
    );
    _writeGroup(buffer, graph, 'Data Layer', ranked, _isData, groupedIds);
    _writeGroup(buffer, graph, 'Widgets', ranked, _isWidget, groupedIds);
    _writeGroup(buffer, graph, 'Routes', ranked, _isRoute, groupedIds);
    _writeGroup(buffer, graph, 'Other', ranked, _isOther, groupedIds);

    final related = ranked
        .where((node) => !groupedIds.contains(node.id))
        .toList();
    if (related.isNotEmpty) {
      buffer.writeln('## Related Nodes');
      buffer.writeln();
      for (final node in related) {
        buffer.writeln(
          '- **${node.name}** (${node.id}) — score ${node.score.toStringAsFixed(2)}',
        );
      }
      buffer.writeln();
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

    var tokens = _baseTokens(scope, observedFlow);
    final selected = <RankedNode>[];
    final activeGroups = <String>{};
    final groupedIds = <String>{};

    for (final node in ranked) {
      final nodeTokens = _estimateNodeTokens(
        node: node,
        graph: graph,
        activeGroups: activeGroups,
        groupedIds: groupedIds,
      );
      if (tokens + nodeTokens > maxTokens) break;
      tokens += nodeTokens;
      selected.add(node);
    }

    return selected;
  }

  void _writeAgentGuide(
    StringBuffer buffer,
    String scope,
    String observedFlow,
    List<RankedNode> ranked,
  ) {
    buffer.writeln('## Agent Guide');
    buffer.writeln();
    buffer.writeln('When changing **$scope**:');
    buffer.writeln('- Follow `$observedFlow` — do not bypass existing layers.');
    buffer.writeln('- Edit files in this feature scope before adding new ones.');
    buffer.writeln('- Reuse repositories, models, and widgets listed below.');
    buffer.writeln('- Do not call HTTP/network APIs directly from UI widgets.');
    if (ranked.any((node) => node.type == NodeType.repository)) {
      buffer.writeln(
        '- Route data access through the feature repository/service layer.',
      );
    }
    buffer.writeln();
  }

  int _baseTokens(String scope, String? observedFlow) {
    var tokens = TokenEstimator.estimate(MarkdownHeader.title('Context: $scope'));
    if (observedFlow != null) {
      tokens += TokenEstimator.estimate('## Observed Flow\n\n$observedFlow\n\n');
      tokens += TokenEstimator.estimate('## Agent Guide\n\n');
    }
    return tokens;
  }

  int _estimateNodeTokens({
    required RankedNode node,
    required ProjectGraph graph,
    required Set<String> activeGroups,
    required Set<String> groupedIds,
  }) {
    final type = node.type;
    String? group;
    if (node.file != null && _isScreen(type)) {
      group = 'Screens';
    } else if (node.file != null && _isState(type)) {
      group = 'State Management';
    } else if (node.file != null && _isData(type)) {
      group = 'Data Layer';
    } else if (node.file != null && _isWidget(type)) {
      group = 'Widgets';
    } else if (node.file != null && _isRoute(type)) {
      group = 'Routes';
    } else if (node.file != null && _isOther(type)) {
      group = 'Other';
    }

    if (group != null) {
      groupedIds.add(node.id);
      var tokens = 0;
      if (activeGroups.add(group)) {
        tokens += TokenEstimator.estimate('## $group\n\n');
      }
      final signature = _signatureFormatter.format(graph, node) ?? node.name;
      tokens += TokenEstimator.estimate(
        '- `${node.file}` — $signature (${node.score.toStringAsFixed(2)})\n\n',
      );
      return tokens;
    }

    return TokenEstimator.estimate(
      '## Related Nodes\n\n- **${node.name}** (${node.id}) — score ${node.score.toStringAsFixed(2)}\n\n',
    );
  }

  void _writeGroup(
    StringBuffer buffer,
    ProjectGraph graph,
    String title,
    List<RankedNode> nodes,
    bool Function(NodeType?) predicate,
    Set<String> groupedIds,
  ) {
    final group = nodes.where((node) => predicate(node.type)).toList();
    if (group.isEmpty) return;

    buffer.writeln('## $title');
    buffer.writeln();
    for (final node in group) {
      if (node.file == null) continue;
      groupedIds.add(node.id);
      final signature = _signatureFormatter.format(graph, node);
      final details = signature ?? node.name;
      buffer.writeln(
        '- `${node.file}` — $details (${node.score.toStringAsFixed(2)})',
      );
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

  bool _isWidget(NodeType? type) => type == NodeType.widget;

  bool _isOther(NodeType? type) {
    return type == null ||
        (!_isScreen(type) &&
            !_isState(type) &&
            !_isData(type) &&
            type != NodeType.widget &&
            !_isRoute(type));
  }

  int estimateTokens(String content) => TokenEstimator.estimate(content);
}
