import '../inference/architecture_inference.dart';
import '../inference/canonical_reference.dart';
import '../inference/state_management_detector.dart';
import '../shared/redaction.dart';

/// Generates AGENTS.md for AI coding agents.
class AgentsMdGenerator {
  String generate({
    required String projectName,
    required StateManagementResult stateManagement,
    required ArchitectureInference architecture,
    required CanonicalReference? canonical,
    String? declaredStateManagement,
    String? interpretation,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('# Flutter Project Context');
    buffer.writeln();
    buffer.writeln('This project uses Flutter.');
    buffer.writeln();
    buffer.writeln('Primary state management:');
    if (declaredStateManagement != null) {
      buffer.writeln(declaredStateManagement);
    } else if (stateManagement.hybridNote != null) {
      buffer.writeln(stateManagement.hybridNote);
    } else {
      buffer.writeln(stateManagement.primary ?? 'Unknown');
    }
    buffer.writeln();
    buffer.writeln('Observed architecture:');
    if (architecture.dominantFlow != null) {
      buffer.writeln(
        '${architecture.dominantFlow} (${architecture.confidence * 100 ~/ 1}% confidence).',
      );
    } else {
      buffer.writeln('Not confidently detected.');
    }
    buffer.writeln();
    if (interpretation != null) {
      buffer.writeln('Interpretation:');
      buffer.writeln(interpretation);
      buffer.writeln();
    }
    buffer.writeln('Important rules:');
    buffer.writeln('- Follow existing feature structure.');
    if (stateManagement.primary != null) {
      buffer.writeln(
        '- Use ${stateManagement.primary} for new state-management code unless a feature is explicitly marked as legacy.',
      );
    }
    buffer.writeln('- Do not call HTTP APIs directly from UI widgets.');
    buffer.writeln(
        '- Reuse existing services and models before creating new ones.');
    buffer.writeln('- Use `.ai/` for detailed project context.');
    buffer.writeln();
    if (canonical != null) {
      buffer.writeln('Canonical architecture reference:');
      buffer.writeln('`${canonical.path}`');
    }
    return Redaction.sanitize(buffer.toString());
  }
}
