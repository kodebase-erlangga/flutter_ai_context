import '../discovery/project_discovery.dart';
import '../inference/architecture_inference.dart';
import '../inference/feature_clustering.dart';
import '../inference/state_management_detector.dart';
import '../shared/redaction.dart';
import 'markdown_header.dart';

/// Generates .ai/project.md
class ProjectMdGenerator {
  String generate({
    required DiscoveryResult discovery,
    required StateManagementResult stateManagement,
    required ArchitectureInference architecture,
    required List<FeatureCluster> features,
  }) {
    final buffer = StringBuffer();
    buffer.write(MarkdownHeader.title('Project Overview'));
    buffer.writeln('**Project:** ${discovery.projectName}');
    buffer.writeln('**Type:** ${discovery.isFlutter ? 'Flutter' : 'Dart'}');
    buffer.writeln('**Files analyzed:** ${discovery.dartFiles.length}');
    buffer.writeln();
    buffer.writeln('## Detected Technologies');
    buffer.writeln();
    buffer.writeln('| Category | Detected |');
    buffer.writeln('|----------|----------|');
    buffer.writeln(
        '| State Management | ${stateManagement.primary ?? 'Unknown'} |');
    buffer.writeln('| Networking | ${discovery.networking ?? 'Unknown'} |');
    buffer.writeln('| Routing | ${discovery.routing ?? 'Unknown'} |');
    buffer.writeln(
        '| Architecture Style | ${discovery.architectureStyle ?? 'Unknown'} |');
    buffer.writeln();
    buffer.writeln('## Features (${features.length})');
    buffer.writeln();
    for (final feature in features) {
      buffer.writeln('- **${feature.name}** (${feature.members.length} files)');
    }
    buffer.writeln();
    if (architecture.dominantFlow != null) {
      buffer.writeln('## Dominant Flow');
      buffer.writeln();
      buffer.writeln('`${architecture.dominantFlow}`');
    }
    return Redaction.sanitize(buffer.toString());
  }
}
