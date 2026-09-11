import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:stream_channel/stream_channel.dart';

import '../cli/runner.dart';
import 'graph_query.dart';
import 'mcp_project_service.dart';
import 'mcp_uris.dart';
import 'project_root.dart';

/// MCP server exposing flutter_ai_context project intelligence.
final class FlutterAiContextMcpServer extends MCPServer
    with ToolsSupport, ResourcesSupport {
  FlutterAiContextMcpServer({
    required StreamChannel<String> channel,
    required McpProjectService service,
    String? projectRoot,
  })  : _service = service,
        _projectRoot = projectRoot,
        super.fromStreamChannel(
          channel,
          implementation: Implementation(
            name: 'flutter_ai_context',
            version: cliVersion,
          ),
          instructions:
              'Local-first Flutter project intelligence from flutter_ai_context. '
              'Use project_status to check FRESH/STALE, sync_context to update, '
              'list_features / get_context for feature packs, query_graph for '
              'graph search, and run_doctor for architecture checks.',
        );

  final McpProjectService _service;
  final String? _projectRoot;

  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) {
    _registerTools();
    _registerResources();
    return super.initialize(request);
  }

  void _registerTools() {
    registerTool(
      Tool(
        name: 'project_status',
        description:
            'Check whether flutter_ai_context is initialized and if context '
            'is FRESH, STALE, or NOT_INITIALIZED.',
        inputSchema: ObjectSchema(),
      ),
      _handleProjectStatus,
    );

    registerTool(
      Tool(
        name: 'list_features',
        description:
            'List available feature scopes for context packs (name + member count).',
        inputSchema: ObjectSchema(),
      ),
      _handleListFeatures,
    );

    registerTool(
      Tool(
        name: 'get_context',
        description:
            'Get token-budgeted Markdown context for a feature scope.',
        inputSchema: ObjectSchema(
          properties: {
            'scope': StringSchema(
              description:
                  'Feature scope name (case-insensitive), e.g. auth, presensi.',
            ),
          },
          required: ['scope'],
        ),
      ),
      _handleGetContext,
    );

    registerTool(
      Tool(
        name: 'sync_context',
        description:
            'Incrementally update project context when STALE or after code changes.',
        inputSchema: ObjectSchema(
          properties: {
            'force': BooleanSchema(
              description: 'Run sync even when context is already FRESH.',
            ),
          },
        ),
      ),
      _handleSyncContext,
    );

    registerTool(
      Tool(
        name: 'run_doctor',
        description:
            'Run architecture consistency checks and return readiness score.',
        inputSchema: ObjectSchema(),
      ),
      _handleRunDoctor,
    );

    registerTool(
      Tool(
        name: 'query_graph',
        description:
            'Search project knowledge graph nodes by type, feature, or name.',
        inputSchema: ObjectSchema(
          properties: {
            'nodeType': StringSchema(
              description:
                  'Node wire type filter, e.g. screen, provider, repository.',
            ),
            'feature': StringSchema(
              description: 'Feature name filter (case-insensitive).',
            ),
            'nameContains': StringSchema(
              description: 'Substring match on node name.',
            ),
            'limit': IntegerSchema(
              description:
                  'Max nodes to return (default ${GraphQuery.defaultLimit}, max ${GraphQuery.maxLimit}).',
            ),
            'offset': IntegerSchema(
              description: 'Pagination offset (default 0).',
            ),
          },
        ),
      ),
      _handleQueryGraph,
    );
  }

  void _registerResources() {
    addResource(
      Resource(
        uri: McpUris.agents,
        name: 'agents',
        description: 'Project AGENTS.md rules for coding agents.',
        mimeType: 'text/markdown',
      ),
      (request) => _textResourceResult(
        request.uri,
        _service.readAgentsMarkdown(overrideRoot: _projectRoot),
        mimeType: 'text/markdown',
      ),
    );

    addResource(
      Resource(
        uri: McpUris.architecture,
        name: 'architecture',
        description: 'Observed architecture summary from .ai/architecture.md.',
        mimeType: 'text/markdown',
      ),
      (request) => _textResourceResult(
        request.uri,
        _service.readArchitectureMarkdown(overrideRoot: _projectRoot),
        mimeType: 'text/markdown',
      ),
    );

    addResource(
      Resource(
        uri: McpUris.graph,
        name: 'graph',
        description:
            'Project knowledge graph JSON (summary when file exceeds size limit).',
        mimeType: 'application/json',
      ),
      (request) => _textResourceResult(
        request.uri,
        _service.readGraphJson(overrideRoot: _projectRoot),
        mimeType: 'application/json',
      ),
    );

    addResourceTemplate(
      ResourceTemplate(
        uriTemplate: McpUris.contextTemplate,
        name: 'feature-context',
        description: 'Per-feature context pack Markdown.',
        mimeType: 'text/markdown',
      ),
      (request) {
        if (!McpUris.isContextUri(request.uri)) return null;
        return _textResourceResult(
          request.uri,
          _service.readContextResource(
            uri: request.uri,
            overrideRoot: _projectRoot,
          ),
          mimeType: 'text/markdown',
        );
      },
    );
  }

  CallToolResult _handleProjectStatus(CallToolRequest request) {
    return _runTool(() {
      final status = _service.projectStatus(overrideRoot: _projectRoot);
      return _service.encodeJson(status);
    });
  }

  CallToolResult _handleListFeatures(CallToolRequest request) {
    return _runTool(() {
      final features = _service.listFeatures(overrideRoot: _projectRoot);
      return _service.encodeJson({'features': features});
    });
  }

  CallToolResult _handleGetContext(CallToolRequest request) {
    final scope = request.arguments?['scope'] as String?;
    if (scope == null || scope.isEmpty) {
      return _errorResult('Missing required argument: scope');
    }

    return _runTool(
      () => _service.getContextMarkdown(
        scope: scope,
        overrideRoot: _projectRoot,
      ),
    );
  }

  Future<CallToolResult> _handleSyncContext(CallToolRequest request) async {
    final force = request.arguments?['force'] as bool? ?? false;
    return _runToolAsync(() async {
      final result = await _service.syncContext(
        force: force,
        overrideRoot: _projectRoot,
      );
      return _service.encodeJson(result);
    });
  }

  Future<CallToolResult> _handleRunDoctor(CallToolRequest request) async {
    return _runToolAsync(() async {
      final result = await _service.runDoctor(overrideRoot: _projectRoot);
      return _service.encodeJson(result);
    });
  }

  CallToolResult _handleQueryGraph(CallToolRequest request) {
    final args = request.arguments ?? {};
    return _runTool(() {
      final result = _service.queryGraph(
        nodeType: args['nodeType'] as String?,
        feature: args['feature'] as String?,
        nameContains: args['nameContains'] as String?,
        limit: (args['limit'] as num?)?.toInt(),
        offset: (args['offset'] as num?)?.toInt(),
        overrideRoot: _projectRoot,
      );
      return _service.encodeJson(result);
    });
  }

  CallToolResult _runTool(String Function() action) {
    try {
      return CallToolResult(
        content: [Content.text(text: action())],
      );
    } on McpProjectException catch (e) {
      return _errorResult(e.message);
    } catch (e) {
      return _errorResult('$e');
    }
  }

  Future<CallToolResult> _runToolAsync(
    Future<String> Function() action,
  ) async {
    try {
      return CallToolResult(
        content: [Content.text(text: await action())],
      );
    } on McpProjectException catch (e) {
      return _errorResult(e.message);
    } catch (e) {
      return _errorResult('$e');
    }
  }

  CallToolResult _errorResult(String message) {
    return CallToolResult(
      content: [Content.text(text: message)],
      isError: true,
    );
  }

  ReadResourceResult _textResourceResult(
    String uri,
    String text, {
    required String mimeType,
  }) {
    try {
      return ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: uri,
            text: text,
            mimeType: mimeType,
          ),
        ],
      );
    } on McpProjectException catch (e) {
      return ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: uri,
            text: e.message,
            mimeType: 'text/plain',
          ),
        ],
      );
    }
  }
}
