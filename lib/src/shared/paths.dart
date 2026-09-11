import 'package:path/path.dart' as p;

/// Project path helpers for cross-platform CLI usage.
class ProjectPaths {
  ProjectPaths(this.root);

  final String root;

  String get configFile => p.join(root, 'flutter_ai_context.yaml');
  String get pubspecFile => p.join(root, 'pubspec.yaml');
  String get agentsMd => p.join(root, 'AGENTS.md');
  String get cursorRulesDir => p.join(root, '.cursor', 'rules');
  String get cursorRuleFile =>
      p.join(cursorRulesDir, 'flutter-ai-context.mdc');
  String get aiDir => p.join(root, '.ai');
  String get cacheDir => p.join(aiDir, 'cache');
  String get contextDir => p.join(aiDir, 'context');

  String get projectGraph => p.join(cacheDir, 'project_graph.json');
  String get filesCache => p.join(cacheDir, 'files.json');
  String get scanMetadata => p.join(cacheDir, 'scan_metadata.json');
  String get schemaVersion => p.join(cacheDir, 'schema_version');

  String aiFile(String name) => p.join(aiDir, name);
  String contextFile(String name) => p.join(contextDir, '$name.md');

  String relative(String absolutePath) {
    return p.relative(absolutePath, from: root);
  }

  String normalize(String filePath) {
    return p.normalize(p.isAbsolute(filePath) ? relative(filePath) : filePath);
  }
}
