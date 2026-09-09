import 'dart:io';

import 'package:flutter_ai_context/src/cli/runner.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  group('CLI', () {
    test('--version returns 0', () async {
      final code = await CliRunner().run(['--version']);
      expect(code, 0);
    });

    test('init works on provider fixture', () async {
      final root = fixturePath('provider_feature_first');
      final code = await CliRunner().run(['init'], projectRoot: root);
      expect(code, 0);
      expect(File('$root/flutter_ai_context.yaml').existsSync(), isTrue);
      expect(Directory('$root/.ai').existsSync(), isTrue);
    });

    test('context requires scope', () async {
      final root = fixturePath('provider_feature_first');
      await CliRunner().run(['init'], projectRoot: root);
      final code = await CliRunner().run(['context'], projectRoot: root);
      expect(code, 64);
    });
  });
}
