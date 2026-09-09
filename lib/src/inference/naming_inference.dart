import '../graph/project_graph.dart';
import '../graph/schema.dart';

/// Naming convention inference result.
class NamingConvention {
  NamingConvention({
    required this.role,
    required this.preferredPattern,
    required this.confidence,
    required this.counts,
  });

  final String role;
  final String preferredPattern;
  final double confidence;
  final Map<String, int> counts;
}

/// Infers naming conventions from observed files.
class NamingInference {
  List<NamingConvention> infer(ProjectGraph graph) {
    final conventions = <NamingConvention>[];

    conventions
        .add(_inferSuffix(graph, NodeType.screen, 'screen', '*_screen.dart'));
    conventions.add(
        _inferSuffix(graph, NodeType.provider, 'provider', '*_provider.dart'));
    conventions.add(
        _inferSuffix(graph, NodeType.service, 'service', '*_service.dart'));
    conventions.add(_inferSuffix(
        graph, NodeType.repository, 'repository', '*_repository.dart'));
    conventions
        .add(_inferSuffix(graph, NodeType.model, 'model', '*_model.dart'));

    return conventions.where((c) => c.counts.isNotEmpty).toList();
  }

  NamingConvention _inferSuffix(
    ProjectGraph graph,
    NodeType type,
    String role,
    String defaultPattern,
  ) {
    final counts = <String, int>{};
    for (final node in graph.nodesByType(type)) {
      final file = node.file;
      if (file == null) continue;
      if (file.endsWith('_screen.dart')) {
        counts['*_screen.dart'] = (counts['*_screen.dart'] ?? 0) + 1;
      } else if (file.endsWith('_page.dart')) {
        counts['*_page.dart'] = (counts['*_page.dart'] ?? 0) + 1;
      } else if (file.endsWith('_view.dart')) {
        counts['*_view.dart'] = (counts['*_view.dart'] ?? 0) + 1;
      } else if (file.endsWith('_provider.dart')) {
        counts['*_provider.dart'] = (counts['*_provider.dart'] ?? 0) + 1;
      } else if (file.endsWith('_service.dart')) {
        counts['*_service.dart'] = (counts['*_service.dart'] ?? 0) + 1;
      } else if (file.endsWith('_repository.dart')) {
        counts['*_repository.dart'] = (counts['*_repository.dart'] ?? 0) + 1;
      } else if (file.endsWith('_model.dart')) {
        counts['*_model.dart'] = (counts['*_model.dart'] ?? 0) + 1;
      } else {
        counts['other'] = (counts['other'] ?? 0) + 1;
      }
    }

    if (counts.isEmpty) {
      return NamingConvention(
        role: role,
        preferredPattern: defaultPattern,
        confidence: 0,
        counts: counts,
      );
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.first;
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return NamingConvention(
      role: role,
      preferredPattern: top.key,
      confidence: top.value / total,
      counts: counts,
    );
  }
}
