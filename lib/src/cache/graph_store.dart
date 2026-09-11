import 'dart:convert';
import 'dart:io';

import '../graph/project_graph.dart';
import '../graph/schema.dart';

/// Persists and loads the project knowledge graph.
class GraphStore {
  GraphStore(this.graphPath, this.schemaVersionPath);

  final String graphPath;
  final String schemaVersionPath;

  /// Set when [load] rejects a cached graph due to schema version mismatch.
  bool schemaMismatch = false;

  /// Cached schema version when [schemaMismatch] is true.
  int? cachedSchemaVersion;

  void save(ProjectGraph graph) {
    final file = File(graphPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(graph.toJson()));
    File(schemaVersionPath).writeAsStringSync(graphSchemaVersion.toString());
  }

  ProjectGraph? load() {
    schemaMismatch = false;
    cachedSchemaVersion = null;

    final file = File(graphPath);
    if (!file.existsSync()) return null;

    final versionFile = File(schemaVersionPath);
    if (versionFile.existsSync()) {
      final version = int.tryParse(versionFile.readAsStringSync().trim());
      if (version != null && version != graphSchemaVersion) {
        schemaMismatch = true;
        cachedSchemaVersion = version;
        return null;
      }
    }

    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final graphVersion = json['schemaVersion'] as int? ?? graphSchemaVersion;
    if (graphVersion != graphSchemaVersion) {
      schemaMismatch = true;
      cachedSchemaVersion = graphVersion;
      return null;
    }

    return ProjectGraph.fromJson(json);
  }
}
