import 'dart:io';

import '../shared/utils.dart';

/// Resolves the Flutter/Dart project root for MCP and CLI commands.
class ProjectRootResolver {
  const ProjectRootResolver();

  /// Priority: [overrideRoot] → `FLUTTER_AI_CONTEXT_ROOT` → [cwd].
  String resolve({String? overrideRoot, String? cwd}) {
    final candidates = <String>[
      if (overrideRoot != null && overrideRoot.isNotEmpty) overrideRoot,
      if (Platform.environment['FLUTTER_AI_CONTEXT_ROOT']?.isNotEmpty ?? false)
        Platform.environment['FLUTTER_AI_CONTEXT_ROOT']!,
      cwd ?? Directory.current.path,
    ];

    for (final candidate in candidates) {
      final normalized = Directory(candidate).absolute.path;
      if (Utils.isDartProject(normalized)) {
        return normalized;
      }
    }

    throw McpProjectException(
      'Not a Dart/Flutter project at ${candidates.last}.\n'
      'Set FLUTTER_AI_CONTEXT_ROOT or run from a project with pubspec.yaml.\n'
      'Run `flutter_ai_context init` to initialize context.',
    );
  }
}

/// Actionable MCP project error with remediation hints.
class McpProjectException implements Exception {
  McpProjectException(this.message);

  final String message;

  @override
  String toString() => message;
}
