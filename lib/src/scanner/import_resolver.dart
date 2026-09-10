import 'package:path/path.dart' as p;

/// Resolves Dart import URIs to project-relative file paths.
class ImportResolver {
  List<String> resolveImports({
    required String sourceFile,
    required List<String> importUris,
  }) {
    final resolved = <String>[];
    final sourceDir = p.dirname(sourceFile);

    for (final uri in importUris) {
      if (uri.startsWith('dart:') ||
          uri.startsWith('package:') ||
          uri.startsWith('asset:')) {
        continue;
      }

      var candidate = uri;
      if (candidate.startsWith('/')) {
        candidate = candidate.substring(1);
      } else {
        candidate = p.normalize(p.join(sourceDir, candidate));
      }

      if (!candidate.endsWith('.dart')) {
        candidate = '$candidate.dart';
      }

      candidate = candidate.replaceAll('\\', '/');
      if (!candidate.startsWith('lib/') && !candidate.startsWith('test/')) {
        continue;
      }
      resolved.add(candidate);
    }

    return resolved.toSet().toList();
  }

  /// Returns project files that import any path in [changedFiles].
  List<String> filesImporting(
    Map<String, List<String>> importsByFile,
    Set<String> changedFiles,
  ) {
    final dependents = <String>{};
    for (final entry in importsByFile.entries) {
      if (entry.value.any(changedFiles.contains)) {
        dependents.add(entry.key);
      }
    }
    return dependents.toList();
  }
}
