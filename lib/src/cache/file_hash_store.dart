import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Cached file metadata for incremental scanning.
class FileCacheEntry {
  FileCacheEntry({
    required this.path,
    required this.hash,
    required this.lastAnalyzed,
    this.analysisVersion = 1,
  });

  final String path;
  final String hash;
  final DateTime lastAnalyzed;
  final int analysisVersion;

  Map<String, dynamic> toJson() => {
        'path': path,
        'hash': hash,
        'lastAnalyzed': lastAnalyzed.toIso8601String(),
        'analysisVersion': analysisVersion,
      };

  factory FileCacheEntry.fromJson(Map<String, dynamic> json) => FileCacheEntry(
        path: json['path'] as String,
        hash: json['hash'] as String,
        lastAnalyzed: DateTime.parse(json['lastAnalyzed'] as String),
        analysisVersion: json['analysisVersion'] as int? ?? 1,
      );
}

/// Stores and compares file content hashes.
class FileHashStore {
  FileHashStore(this.cachePath);

  final String cachePath;
  final Map<String, FileCacheEntry> _entries = {};

  Map<String, FileCacheEntry> get entries => Map.unmodifiable(_entries);

  void load() {
    _entries.clear();
    final file = File(cachePath);
    if (!file.existsSync()) return;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final files = json['files'] as List<dynamic>? ?? [];
    for (final item in files) {
      final entry = FileCacheEntry.fromJson(item as Map<String, dynamic>);
      _entries[entry.path] = entry;
    }
  }

  void save() {
    final file = File(cachePath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      jsonEncode({
        'files': _entries.values.map((e) => e.toJson()).toList(),
      }),
    );
  }

  static String hashContent(String content) {
    return sha256.convert(utf8.encode(content)).toString();
  }

  static String hashFile(String absolutePath) {
    final content = File(absolutePath).readAsStringSync();
    return hashContent(content);
  }

  List<String> findChangedFiles(String root, List<String> dartFiles) {
    final changed = <String>[];
    for (final relative in dartFiles) {
      final absolute =
          '$root${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}';
      if (!File(absolute).existsSync()) {
        changed.add(relative);
        continue;
      }
      final hash = hashFile(absolute);
      final cached = _entries[relative];
      if (cached == null || cached.hash != hash) {
        changed.add(relative);
      }
    }
    return changed;
  }

  void updateEntry(String path, String hash) {
    _entries[path] = FileCacheEntry(
      path: path,
      hash: hash,
      lastAnalyzed: DateTime.now(),
    );
  }
}
