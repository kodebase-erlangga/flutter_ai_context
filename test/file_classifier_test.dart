import 'package:flutter_ai_context/src/graph/schema.dart';
import 'package:flutter_ai_context/src/scanner/classifiers/file_classifier.dart';
import 'package:test/test.dart';

void main() {
  final classifier = FileClassifier();

  test('classifies Screen widgets', () {
    final result = classifier.classifyClass(
      filePath: 'lib/features/auth/auth_screen.dart',
      className: 'AuthScreen',
      superClass: 'StatelessWidget',
      implementedTypes: const [],
      mixins: const [],
      hasBuildMethod: true,
      methodNames: const ['build'],
      imports: const ['package:flutter/material.dart'],
    );

    expect(result.nodeType, NodeType.screen);
  });

  test('classifies Page widgets as screens', () {
    final result = classifier.classifyClass(
      filePath: 'lib/features/presensi/presentation/pages/presensi_page.dart',
      className: 'PresensiPage',
      superClass: 'StatelessWidget',
      implementedTypes: const [],
      mixins: const [],
      hasBuildMethod: true,
      methodNames: const ['build'],
      imports: const ['package:flutter/material.dart'],
    );

    expect(result.nodeType, NodeType.screen);
    expect(result.featureHint, 'Presensi');
  });

  test('classifies GetX hybrid ChangeNotifier controllers', () {
    final result = classifier.classifyClass(
      filePath:
          'lib/features/presensi/presentation/controllers/presensi_controller.dart',
      className: 'PresensiController',
      superClass: 'ChangeNotifier',
      implementedTypes: const [],
      mixins: const [],
      hasBuildMethod: false,
      methodNames: const ['load'],
      imports: const ['package:flutter/foundation.dart'],
    );

    expect(result.nodeType, NodeType.notifier);
    expect(result.stateManagementFramework, 'getx');
  });

  test('classifies GetX bindings', () {
    final result = classifier.classifyClass(
      filePath: 'lib/features/auth/bindings/auth_binding.dart',
      className: 'AuthBinding',
      superClass: 'Bindings',
      implementedTypes: const [],
      mixins: const [],
      hasBuildMethod: false,
      methodNames: const ['dependencies'],
      imports: const ['package:get/get.dart'],
    );

    expect(result.stateManagementFramework, 'getx');
  });
}
