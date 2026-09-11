import 'dart:convert';
import 'dart:io';

import '../graph/project_graph.dart';
import '../shared/paths.dart';
import 'file_hash_store.dart';
import 'graph_store.dart';

/// Scan metadata persisted between runs.
class ScanMetadata {
  ScanMetadata({
    required this.lastScan,
    required this.filesAnalyzed,
    required this.featureCount,
    this.projectName,
    this.isStale = false,
    this.changedFileCount = 0,
  });

  final DateTime lastScan;
  final int filesAnalyzed;
  final int featureCount;
  final String? projectName;
  final bool isStale;
  final int changedFileCount;

  Map<String, dynamic> toJson() => {
        'lastScan': lastScan.toIso8601String(),
        'filesAnalyzed': filesAnalyzed,
        'featureCount': featureCount,
        if (projectName != null) 'projectName': projectName,
        'isStale': isStale,
        'changedFileCount': changedFileCount,
      };

  factory ScanMetadata.fromJson(Map<String, dynamic> json) => ScanMetadata(
        lastScan: DateTime.parse(json['lastScan'] as String),
        filesAnalyzed: json['filesAnalyzed'] as int? ?? 0,
        featureCount: json['featureCount'] as int? ?? 0,
        projectName: json['projectName'] as String?,
        isStale: json['isStale'] as bool? ?? false,
        changedFileCount: json['changedFileCount'] as int? ?? 0,
      );
}

/// Manages cache files for incremental analysis.
class CacheManager {
  CacheManager(ProjectPaths paths)
      : _paths = paths,
        _hashStore = FileHashStore(paths.filesCache),
        _graphStore = GraphStore(paths.projectGraph, paths.schemaVersion);

  final ProjectPaths _paths;
  final FileHashStore _hashStore;
  final GraphStore _graphStore;

  FileHashStore get hashStore => _hashStore;

  void ensureDirectories() {
    Directory(_paths.aiDir).createSync(recursive: true);
    Directory(_paths.cacheDir).createSync(recursive: true);
    Directory(_paths.contextDir).createSync(recursive: true);
  }

  void load() {
    _hashStore.load();
  }

  ProjectGraph? loadGraph() => _graphStore.load();

  bool get schemaMismatch => _graphStore.schemaMismatch;

  int? get cachedSchemaVersion => _graphStore.cachedSchemaVersion;

  void saveGraph(ProjectGraph graph) => _graphStore.save(graph);

  void saveHashes() => _hashStore.save();

  ScanMetadata? loadMetadata() {
    final file = File(_paths.scanMetadata);
    if (!file.existsSync()) return null;
    return ScanMetadata.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
  }

  void saveMetadata(ScanMetadata metadata) {
    final file = File(_paths.scanMetadata);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(metadata.toJson()),
    );
  }

  int countChangedFiles(String root, List<String> allFiles) {
    return _hashStore.findChangedFiles(root, allFiles).length;
  }

  List<String> changedFiles(String root, List<String> allFiles) {
    return _hashStore.findChangedFiles(root, allFiles);
  }

  void updateFileHashes(String root, List<String> files) {
    for (final relative in files) {
      final absolute =
          '$root${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}';
      if (File(absolute).existsSync()) {
        _hashStore.updateEntry(relative, FileHashStore.hashFile(absolute));
      }
    }
    saveHashes();
  }
}
