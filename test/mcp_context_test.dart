import 'dart:io';

import 'package:flutter_ai_context/src/config/models/mcp_settings.dart';
import 'package:flutter_ai_context/src/config/models/project_config.dart';
import 'package:flutter_ai_context/src/mcp/mcp_prompt_builder.dart';
import 'package:flutter_ai_context/src/mcp/mcp_project_service.dart';
import 'package:flutter_ai_context/src/shared/paths.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  group('MCP context (Phase 3)', () {
    test('McpSettings defaults and yaml roundtrip', () {
      const settings = McpSettings();
      expect(settings.autoSyncOnGetContext, isTrue);
      expect(settings.includeProjectBrief, isTrue);

      final restored =
          McpSettings.fromYamlMap(const McpSettings().toYamlMap());
      expect(restored.autoSyncOnGetContext, isTrue);
      expect(restored.includeProjectBrief, isTrue);

      final config = ProjectConfig.fromYamlMap(
        const ProjectConfig(
          mcp: McpSettings(
            autoSyncOnGetContext: false,
            includeProjectBrief: false,
          ),
        ).toYamlMap(),
      );
      expect(config.mcp.autoSyncOnGetContext, isFalse);
      expect(config.mcp.includeProjectBrief, isFalse);
    });

    test('projectBriefFromAgents stops before Important rules', () {
      const agents = '''
# Flutter Project Context

Primary state management:
GetX

Observed architecture:
Page -> GetX Controller -> Repository (44% confidence).

Important rules:
- Follow existing feature structure.
''';

      final brief = McpPromptBuilder.projectBriefFromAgents(agents);
      expect(brief, contains('GetX'));
      expect(brief, isNot(contains('Important rules')));
    });

    test('getContext prepends project overview when enabled', () async {
      final root = fixturePath('provider_feature_first');
      final service = McpProjectService();

      final result = await service.getContext(
        scope: 'attendance',
        autoSync: false,
        includeProjectBrief: true,
        overrideRoot: root,
      );

      expect(result.markdown, contains('## Project Overview'));
      expect(result.markdown.toLowerCase(), contains('# context: attendance'));
      expect(result.contextStatus, 'FRESH');
      expect(result.autoSynced, isFalse);
    });

    test('getContext auto-syncs when a tracked file changes', () async {
      final root = fixturePath('provider_feature_first');
      final paths = ProjectPaths(root);
      final target = File('${root}/lib/features/attendance/attendance_screen.dart');
      final original = target.readAsStringSync();
      target.writeAsStringSync('$original\n// mcp auto-sync test\n');

      try {
        final service = McpProjectService();
        final before = service.projectStatus(overrideRoot: root);
        expect(before['context'], 'STALE');

        final result = await service.getContext(
          scope: 'attendance',
          autoSync: true,
          includeProjectBrief: false,
          overrideRoot: root,
        );

        expect(result.autoSynced, isTrue);
        expect(result.filesSynced, greaterThan(0));
        expect(result.markdown.toLowerCase(), contains('# context: attendance'));

        final after = service.projectStatus(overrideRoot: root);
        expect(after['context'], 'FRESH');
      } finally {
        target.writeAsStringSync(original);
        if (File(paths.configFile).existsSync()) {
          await McpProjectService().syncContext(overrideRoot: root);
        }
      }
    });
  });
}
