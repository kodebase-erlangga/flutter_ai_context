import 'dart:async';

import 'package:dart_mcp/client.dart';
import 'package:dart_mcp/server.dart';
import 'package:flutter_ai_context/src/analysis/analysis_pipeline.dart';
import 'package:flutter_ai_context/src/cache/cache_manager.dart';
import 'package:flutter_ai_context/src/config/models/project_config.dart';
import 'package:flutter_ai_context/src/mcp/flutter_ai_context_mcp_server.dart';
import 'package:flutter_ai_context/src/mcp/mcp_project_service.dart';
import 'package:flutter_ai_context/src/mcp/mcp_uris.dart';
import 'package:flutter_ai_context/src/shared/paths.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

class _McpTestEnvironment {
  _McpTestEnvironment({
    required String projectRoot,
    MCPClient? client,
  })  : projectRoot = projectRoot,
        client = client ?? MCPClient(Implementation(name: 'test', version: '1')) {
    final activeClient = this.client;
    server = FlutterAiContextMcpServer(
      channel: serverChannel,
      service: McpProjectService(),
      projectRoot: projectRoot,
    );
    serverConnection = activeClient.connectServer(clientChannel);
    addTearDown(shutdown);
  }

  final String projectRoot;
  final MCPClient client;
  late final FlutterAiContextMcpServer server;
  late final ServerConnection serverConnection;

  final _clientController = StreamController<String>();
  final _serverController = StreamController<String>();

  late final StreamChannel<String> clientChannel =
      StreamChannel<String>.withCloseGuarantee(
    _serverController.stream,
    _clientController.sink,
  );

  late final StreamChannel<String> serverChannel =
      StreamChannel<String>.withCloseGuarantee(
    _clientController.stream,
    _serverController.sink,
  );

  Future<InitializeResult> initializeServer() async {
    final result = await serverConnection.initialize(
      InitializeRequest(
        protocolVersion: ProtocolVersion.latestSupported,
        capabilities: client.capabilities,
        clientInfo: client.implementation,
      ),
    );
    if (result.protocolVersion?.isSupported == true) {
      serverConnection.notifyInitialized(InitializedNotification());
      await server.initialized;
    }
    return result;
  }

  Future<void> shutdown() async {
    await client.shutdown();
    await server.shutdown();
    await _clientController.close();
    await _serverController.close();
  }
}

Future<void> _seedFixture(String fixtureName) async {
  final root = fixturePath(fixtureName);
  final paths = ProjectPaths(root);
  final cache = CacheManager(paths);
  await AnalysisPipeline().run(
    root: root,
    config: ProjectConfig(projectName: fixtureName),
    paths: paths,
    cache: cache,
  );
}

void main() {
  group('MCP server', () {
    late _McpTestEnvironment environment;

    setUp(() async {
      await _seedFixture('provider_feature_first');
      environment = _McpTestEnvironment(
        projectRoot: fixturePath('provider_feature_first'),
      );
      await environment.initializeServer();
    });

    test('exposes phase 1, 2, and 3 tools', () async {
      final tools = await environment.serverConnection.listTools();
      expect(
        tools.tools.map((t) => t.name),
        containsAll([
          'project_status',
          'list_features',
          'get_context',
          'get_architecture',
          'sync_context',
          'run_doctor',
          'query_graph',
        ]),
      );
    });

    test('exposes flutter-feature-context prompt', () async {
      final prompts = await environment.serverConnection.listPrompts();
      expect(
        prompts.prompts.map((prompt) => prompt.name),
        contains('flutter-feature-context'),
      );

      final prompt = await environment.serverConnection.getPrompt(
        GetPromptRequest(
          name: 'flutter-feature-context',
          arguments: {'scope': 'attendance'},
        ),
      );
      final text = (prompt.messages.single.content as TextContent).text;
      expect(text, contains('attendance'));
      expect(text.toLowerCase(), contains('context: attendance'));
      expect(text, contains('Project overview'));
    });

    test('project_status returns FRESH for seeded fixture', () async {
      final result = await environment.serverConnection.callTool(
        CallToolRequest(name: 'project_status'),
      );

      expect(result.isError, isNot(true));
      final text = (result.content.single as TextContent).text;
      expect(text, contains('"context": "FRESH"'));
      expect(text, contains('provider_feature_first'));
    });

    test('list_features returns attendance and grade scopes', () async {
      final result = await environment.serverConnection.callTool(
        CallToolRequest(name: 'list_features'),
      );

      final text = (result.content.single as TextContent).text;
      expect(text, contains('Attendance'));
      expect(text, contains('Grade'));
    });

    test('get_context returns markdown for attendance scope', () async {
      final result = await environment.serverConnection.callTool(
        CallToolRequest(
          name: 'get_context',
          arguments: {'scope': 'attendance'},
        ),
      );

      expect(result.isError, isNot(true));
      final text = (result.content.single as TextContent).text;
      expect(text.toLowerCase(), contains('# context: attendance'));
      expect(text, contains('Observed Flow'));
    });

    test('resources expose agents, architecture, and features', () async {
      final resources = await environment.serverConnection.listResources();
      expect(
        resources.resources.map((r) => r.uri),
        containsAll([
          McpUris.agents,
          McpUris.architecture,
          McpUris.features,
        ]),
      );

      final agents = await environment.serverConnection.readResource(
        ReadResourceRequest(uri: McpUris.agents),
      );
      expect(
        (agents.contents.single as TextResourceContents).text,
        contains('Flutter Project Context'),
      );
    });

    test('sync_context skips when already FRESH', () async {
      final result = await environment.serverConnection.callTool(
        CallToolRequest(name: 'sync_context'),
      );

      expect(result.isError, isNot(true));
      final text = (result.content.single as TextContent).text;
      expect(text, contains('"synced": false'));
      expect(text, contains('"context": "FRESH"'));
    });

    test('run_doctor returns readiness score', () async {
      final result = await environment.serverConnection.callTool(
        CallToolRequest(name: 'run_doctor'),
      );

      expect(result.isError, isNot(true));
      final text = (result.content.single as TextContent).text;
      expect(text, contains('readinessScore'));
      expect(text, contains('AI Readiness Score'));
    });

    test('query_graph filters attendance screens', () async {
      final result = await environment.serverConnection.callTool(
        CallToolRequest(
          name: 'query_graph',
          arguments: {
            'nodeType': 'screen',
            'feature': 'Attendance',
          },
        ),
      );

      expect(result.isError, isNot(true));
      final text = (result.content.single as TextContent).text;
      expect(text, contains('AttendanceScreen'));
    });

    test('graph resource returns JSON', () async {
      final resources = await environment.serverConnection.listResources();
      expect(resources.resources.map((r) => r.uri), contains(McpUris.graph));

      final graph = await environment.serverConnection.readResource(
        ReadResourceRequest(uri: McpUris.graph),
      );
      final text = (graph.contents.single as TextResourceContents).text;
      expect(text, contains('"schemaVersion"'));
      expect(text, contains('"nodes"'));
    });

    test('context resource template serves feature markdown', () async {
      final templates =
          await environment.serverConnection.listResourceTemplates();
      expect(
        templates.resourceTemplates.single.uriTemplate,
        McpUris.contextTemplate,
      );

      final context = await environment.serverConnection.readResource(
        ReadResourceRequest(uri: 'flutter-ai-context://context/attendance'),
      );
      expect(
        (context.contents.single as TextResourceContents).text.toLowerCase(),
        contains('# context: attendance'),
      );
    });
  });
}
