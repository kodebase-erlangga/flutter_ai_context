import 'package:dart_mcp/server.dart';

import 'mcp_get_context_result.dart';

/// Builds MCP prompt responses for flutter_ai_context.
class McpPromptBuilder {
  /// Extracts the project overview from AGENTS.md (up to Important rules).
  static String projectBriefFromAgents(String agentsMarkdown) {
    final lines = agentsMarkdown.split('\n');
    final buffer = StringBuffer();
    for (final line in lines) {
      if (line.startsWith('Important rules:')) break;
      buffer.writeln(line);
    }
    return buffer.toString().trim();
  }

  /// Combines project brief and feature context for agent prompts.
  static String combineFeaturePrompt({
    required String scope,
    required String projectBrief,
    required String featureMarkdown,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('You are working on the **$scope** feature in a Flutter project.');
    buffer.writeln();
    if (projectBrief.isNotEmpty) {
      buffer.writeln('## Project overview');
      buffer.writeln();
      buffer.writeln(projectBrief);
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }
    buffer.writeln(featureMarkdown);
    return buffer.toString().trim();
  }

  /// Builds the `flutter-feature-context` MCP prompt.
  static GetPromptResult featureContextPrompt({
    required String scope,
    required McpGetContextResult context,
    required String projectBrief,
  }) {
    final text = combineFeaturePrompt(
      scope: scope,
      projectBrief: projectBrief,
      featureMarkdown: context.markdown,
    );

    return GetPromptResult(
      description: 'Feature context for $scope with project architecture brief.',
      messages: [
        PromptMessage(
          role: Role.user,
          content: Content.text(text: text),
        ),
      ],
    );
  }
}
