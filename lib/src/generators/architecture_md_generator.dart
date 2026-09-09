import '../inference/architecture_inference.dart';
import '../inference/state_management_detector.dart';
import '../shared/redaction.dart';
import 'markdown_header.dart';

/// Generates .ai/architecture.md
class ArchitectureMdGenerator {
  String generate({
    required StateManagementResult stateManagement,
    required ArchitectureInference architecture,
    String? declaredStateManagement,
  }) {
    final buffer = StringBuffer();
    buffer.write(MarkdownHeader.title('Architecture'));

    if (declaredStateManagement != null) {
      buffer.writeln('## Declared Architecture');
      buffer.writeln();
      buffer.writeln('State management: **$declaredStateManagement**');
      buffer.writeln();
    }

    buffer.writeln('## Observed Architecture');
    buffer.writeln();
    buffer.writeln('### State Management');
    buffer.writeln();
    for (final entry in stateManagement.distribution.entries) {
      buffer.writeln('- ${entry.key}: ${entry.value.toStringAsFixed(0)}%');
    }
    if (stateManagement.secondary != null) {
      buffer.writeln();
      buffer.writeln(
        'Secondary/legacy pattern: **${stateManagement.secondary}**',
      );
    }
    buffer.writeln();
    buffer.writeln('Evidence:');
    for (final e in stateManagement.evidence) {
      buffer.writeln('- $e');
    }
    buffer.writeln();
    buffer.writeln('### Dominant Flows');
    buffer.writeln();
    for (final flow in architecture.flows) {
      buffer.writeln(
        '- `${flow.pattern}` — ${flow.percentage.toStringAsFixed(0)}% (${flow.count} features)',
      );
    }
    return Redaction.sanitize(buffer.toString());
  }
}
