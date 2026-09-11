/// Generates a Cursor rule that points agents to flutter_ai_context output.
class CursorRuleGenerator {
  String generate({
    required String projectName,
    String? primaryStateManagement,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln(
      'description: Flutter AI Context — project conventions for $projectName',
    );
    buffer.writeln('alwaysApply: true');
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln('# Flutter AI Context');
    buffer.writeln();
    buffer.writeln(
      'This project uses **flutter_ai_context** for local, graph-based project intelligence.',
    );
    buffer.writeln();
    buffer.writeln('## Read first');
    buffer.writeln('- `AGENTS.md` — primary rules for coding agents');
    buffer.writeln(
      '- `.ai/` — architecture, features, routes, services, and models',
    );
    buffer.writeln();
    if (primaryStateManagement != null) {
      buffer.writeln('Primary state management: **$primaryStateManagement**');
      buffer.writeln();
    }
    buffer.writeln('## Workflow');
    buffer.writeln('After code changes, refresh context with:');
    buffer.writeln();
    buffer.writeln('```bash');
    buffer.writeln('dart run flutter_ai_context sync');
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln(
      'Check freshness with `dart run flutter_ai_context status`. '
      'Use `scan` only for a full rebuild (schema upgrade or major refactor).',
    );
    buffer.writeln();
    buffer.writeln('## Rules');
    buffer.writeln('- Follow existing feature structure.');
    buffer.writeln('- Do not call HTTP APIs directly from UI widgets.');
    buffer.writeln(
      '- Reuse existing services and models before creating new ones.',
    );
    return buffer.toString();
  }
}
