import '../graph/project_graph.dart';
import 'relevance_ranker.dart';

/// Formats a compact class signature from graph metadata.
class ClassSignatureFormatter {
  String? format(ProjectGraph graph, RankedNode node) {
    final graphNode = graph.findNode(node.id);
    if (graphNode == null) return null;

    final superType = graphNode.metadata['superType'] as String?;
    final methods = (graphNode.metadata['methods'] as List?)
            ?.map((method) => method.toString())
            .toList() ??
        const <String>[];

    final parts = <String>[node.name];
    if (superType != null && superType.isNotEmpty) {
      parts.add('extends $superType');
    }
    if (methods.isNotEmpty) {
      parts.add(methods.take(6).join(', '));
    }
    return parts.join(' · ');
  }
}
