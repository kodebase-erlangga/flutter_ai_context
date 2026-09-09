import 'dart:io';

import 'package:flutter_ai_context/src/config/config_loader.dart';
import 'package:flutter_ai_context/src/config/models/project_config.dart';
import 'package:test/test.dart';

void main() {
  test('ConfigLoader quotes glob patterns in generated yaml', () {
    final dir = Directory.systemTemp.createTempSync('fac_config_');
    final path = '${dir.path}/flutter_ai_context.yaml';
    ConfigLoader().writeDefault(path, const ProjectConfig());
    final content = File(path).readAsStringSync();
    expect(content, contains("'**/*.g.dart'"));
    final loaded = ConfigLoader().load(path);
    expect(loaded.ignorePatterns, contains('**/*.g.dart'));
  });

  test('ProjectConfig roundtrips through yaml map', () {
    const config = ProjectConfig(
      projectName: 'test_app',
      stateManagement: 'riverpod',
      preferredScreenSuffix: '_screen',
    );

    final restored = ProjectConfig.fromYamlMap(config.toYamlMap());
    expect(restored.projectName, 'test_app');
    expect(restored.stateManagement, 'riverpod');
    expect(restored.preferredScreenSuffix, '_screen');
  });
}
