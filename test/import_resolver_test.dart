import 'package:flutter_ai_context/src/scanner/import_resolver.dart';
import 'package:test/test.dart';

void main() {
  test('resolves relative imports to project paths', () {
    final resolver = ImportResolver();
    final resolved = resolver.resolveImports(
      sourceFile: 'lib/features/home/home_screen.dart',
      importUris: [
        '../attendance/attendance_service.dart',
        'package:flutter/material.dart',
        'dart:async',
      ],
    );

    expect(resolved, contains('lib/features/attendance/attendance_service.dart'));
    expect(resolved.length, 1);
  });

  test('finds files importing changed modules', () {
    final resolver = ImportResolver();
    final dependents = resolver.filesImporting(
      {
        'lib/features/home/home_screen.dart': [
          'lib/features/attendance/attendance_service.dart',
        ],
        'lib/features/attendance/attendance_screen.dart': [
          'lib/features/attendance/attendance_provider.dart',
        ],
      },
      {'lib/features/attendance/attendance_service.dart'},
    );

    expect(dependents, contains('lib/features/home/home_screen.dart'));
  });
}
