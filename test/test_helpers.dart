import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves fixture path independent of current working directory.
String fixturePath(String name) {
  final candidates = [
    p.join(Directory.current.path, 'test', 'fixtures', name),
    p.join(Directory.current.path, 'fixtures', name),
    p.join(_findPackageRoot(), 'test', 'fixtures', name),
  ];

  for (final candidate in candidates) {
    if (File(p.join(candidate, 'pubspec.yaml')).existsSync()) {
      return p.normalize(candidate);
    }
  }

  throw StateError('Fixture not found: $name');
}

String _findPackageRoot() {
  var current = Directory.current;
  while (true) {
    final pubspec = File(p.join(current.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      if (content.contains('name: flutter_ai_context')) {
        return current.path;
      }
    }
    if (current.parent.path == current.path) break;
    current = current.parent;
  }
  return Directory.current.path;
}
