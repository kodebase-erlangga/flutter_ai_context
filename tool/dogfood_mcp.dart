// Dogfood MCP tools against a real Flutter project root.
//
// Usage:
//   dart run tool/dogfood_mcp.dart <project_root>
import 'dart:convert';
import 'dart:io';

import 'package:flutter_ai_context/src/mcp/mcp_project_service.dart';

Future<void> main(List<String> args) async {
  final root = args.isNotEmpty ? args.first : Directory.current.path;
  final service = McpProjectService();
  final encoder = const JsonEncoder.withIndent('  ');

  void section(String title) {
    stdout.writeln();
    stdout.writeln('=== $title ===');
  }

  stdout.writeln('Dogfood MCP — $root');

  section('project_status');
  stdout.writeln(encoder.convert(service.projectStatus(overrideRoot: root)));

  section('list_features');
  final features = service.listFeatures(overrideRoot: root);
  stdout.writeln('count: ${features.length}');
  for (final f in features.take(5)) {
    stdout.writeln('  - ${f['name']} (${f['members']} members)');
  }
  if (features.length > 5) {
    stdout.writeln('  ... +${features.length - 5} more');
  }

  section('get_context (presensi, with project brief)');
  final presensiResult = await service.getContext(
    scope: 'presensi',
    autoSync: false,
    includeProjectBrief: true,
    overrideRoot: root,
  );
  final presensi = presensiResult.markdown;
  final presensiLines = presensi.split('\n');
  stdout.writeln(presensiLines.take(20).join('\n'));
  if (presensiLines.length > 20) stdout.writeln('...');

  try {
    section('run_doctor');
    final doctor = await service.runDoctor(overrideRoot: root);
    stdout.writeln('readiness: ${doctor['readinessScore']}');
    stdout.writeln('observed: ${doctor['observedArchitecture']}');
    stdout.writeln('findings: ${(doctor['findings'] as List).length}');

    section('query_graph (GetX notifiers in Auth)');
    stdout.writeln(
      encoder.convert(
        service.queryGraph(
          overrideRoot: root,
          nodeType: 'notifier',
          feature: 'Auth',
          limit: 5,
        ),
      ),
    );

    section('sync_context');
    final sync = await service.syncContext(overrideRoot: root);
    stdout.writeln(encoder.convert(sync));

    section('prompt: flutter-feature-context (presensi)');
    final prompt = await service.buildFeatureContextPrompt(
      scope: 'presensi',
      overrideRoot: root,
    );
    stdout.writeln(prompt.markdown.split('\n').take(25).join('\n'));
    if (prompt.markdown.split('\n').length > 25) stdout.writeln('...');

    section('get_architecture (excerpt)');
    stdout.writeln(
      service
          .readArchitectureMarkdown(overrideRoot: root)
          .split('\n')
          .take(15)
          .join('\n'),
    );

    section('resource: agents');
    final agents = service.readAgentsMarkdown(overrideRoot: root);
    stdout.writeln(agents.split('\n').take(12).join('\n'));

    section('resource: graph (summary check)');
    final graphJson = service.readGraphJson(overrideRoot: root);
    final parsed = jsonDecode(graphJson) as Map<String, dynamic>;
    if (parsed.containsKey('truncated')) {
      stdout.writeln('truncated summary: ${encoder.convert(parsed)}');
    } else {
      stdout.writeln('full graph bytes: ${graphJson.length}');
      stdout.writeln('nodeCount: ${(parsed['nodes'] as List).length}');
    }

    section('DONE');
    stdout.writeln('All MCP operations completed successfully.');
  } on Object catch (e, st) {
    stderr.writeln('FAILED: $e');
    stderr.writeln(st);
    exitCode = 1;
  }
}
