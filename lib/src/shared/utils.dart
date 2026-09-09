import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

/// Shared utility functions.
class Utils {
  static bool isFlutterProject(String root) {
    final pubspec = File(p.join(root, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return false;
    final content = pubspec.readAsStringSync();
    return content.contains('flutter:') ||
        content.contains('flutter_test:') ||
        Directory(p.join(root, 'lib')).existsSync();
  }

  static bool isDartProject(String root) {
    return File(p.join(root, 'pubspec.yaml')).existsSync();
  }

  static List<String> findDartFiles(
    String root,
    List<String> scanPaths,
    List<String> ignorePatterns,
  ) {
    final files = <String>[];
    for (final scanPath in scanPaths) {
      final dir = Directory(p.join(root, scanPath));
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.dart')) continue;
        final relative = p.relative(entity.path, from: root);
        if (_shouldIgnore(relative, ignorePatterns)) continue;
        files.add(relative.replaceAll('\\', '/'));
      }
    }
    files.sort();
    return files;
  }

  static bool _shouldIgnore(String relativePath, List<String> patterns) {
    for (final pattern in patterns) {
      if (Glob(pattern).matches(relativePath)) return true;
    }
    return false;
  }

  static String formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
    if (d.inHours > 0) {
      return '${d.inHours} hour${d.inHours == 1 ? '' : 's'} ago';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes} minute${d.inMinutes == 1 ? '' : 's'} ago';
    }
    return 'just now';
  }
}
