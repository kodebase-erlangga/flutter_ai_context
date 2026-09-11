import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:stream_channel/stream_channel.dart';

import '../cli/runner.dart';
import 'graph_query.dart';
import 'mcp_prompt_builder.dart';
import 'mcp_project_service.dart';
import 'mcp_uris.dart';
import 'project_root.dart';

/// MCP server exposing flutter_ai_context project intelligence.
final class FlutterAiContextMcpServer extends MCPServer
    with ToolsSupport, ResourcesSupport, PromptsSupport {
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
              'list_features / get_context for feature packs (auto-syncs when STALE), '
              'prompt flutter-feature-context for combined project + feature context, '
              'query_graph for graph search, and run_doctor for architecture checks.',
        );

  final McpProjectService _service;
  final String? _projectRoot;

  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) {
    _registerTools();
    _registerResources();
    _registerPrompts();
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
            'Get token-budgeted Markdown context for a feature scope. '
            'Auto-syncs when STALE unless disabled in flutter_ai_context.yaml.',
        inputSchema: ObjectSchema(
          properties: {
            'scope': StringSchema(
              description:
                  'Feature scope name (case-insensitive), e.g. auth, presensi.',
            ),
            'autoSync': BooleanSchema(
              description:
                  'Override mcp.auto_sync_on_get_context (default: true).',
            ),
            'includeProjectBrief': BooleanSchema(
              description:
                  'Prepend project overview from AGENTS.md (default: true).',
            ),
          },
          required: ['scope'],
        ),
      ),
      _handleGetContext,
    );

    registerTool(
      Tool(
        name: 'get_architecture',
        description:
            'Get observed architecture summary Markdown (.ai/architecture.md).',
        inputSchema: ObjectSchema(),
      ),
      _handleGetArchitecture,
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

    addResource(
      Resource(
        uri: McpUris.features,
        name: 'features',
        description: 'Feature index from .ai/features.md.',
        mimeType: 'text/markdown',
      ),
      (request) => _textResourceResult(
        request.uri,
        _service.readFeaturesMarkdown(overrideRoot: _projectRoot),
        mimeType: 'text/markdown',
      ),
    );

    addResourceTemplate(
      ResourceTemplate(
        uriTemplate: McpUris.contextTemplate,
        name: 'feature-context',
        description:
            'Per-feature context pack Markdown (auto-syncs when STALE).',
        mimeType: 'text/markdown',
      ),
      (request) async {
        if (!McpUris.isContextUri(request.uri)) return null;
        final text = await _service.readContextResource(
          uri: request.uri,
          overrideRoot: _projectRoot,
        );
        return _textResourceResult(
          request.uri,
          text,
          mimeType: 'text/markdown',
        );
      },
    );
  }

  void _registerPrompts() {
    addPrompt(
      Prompt(
        name: 'flutter-feature-context',
        description:
            'Combined project architecture brief and feature context pack.',
        arguments: [
          PromptArgument(
            name: 'scope',
            description: 'Feature scope name (case-insensitive).',
            required: true,
          ),
        ],
      ),
      (request) async {
        final scope = request.arguments?['scope'] as String?;
        if (scope == null || scope.isEmpty) {
          throw ArgumentError('Missing required prompt argument: scope');
        }

        final context = await _service.getContext(
          scope: scope,
          includeProjectBrief: false,
          overrideRoot: _projectRoot,
        );
        final agents = _service.readAgentsMarkdown(overrideRoot: _projectRoot);
        return McpPromptBuilder.featureContextPrompt(
          scope: scope,
          context: context,
          projectBrief: McpPromptBuilder.projectBriefFromAgents(agents),
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

  Future<CallToolResult> _handleGetContext(CallToolRequest request) async {
    final scope = request.arguments?['scope'] as String?;
    if (scope == null || scope.isEmpty) {
      return _errorResult('Missing required argument: scope');
    }

    final args = request.arguments ?? {};
    return _runToolAsync(() async {
      final result = await _service.getContext(
        scope: scope,
        autoSync: args['autoSync'] as bool?,
        includeProjectBrief: args['includeProjectBrief'] as bool?,
        overrideRoot: _projectRoot,
      );
      return result.markdown;
    });
  }

  CallToolResult _handleGetArchitecture(CallToolRequest request) {
    return _runTool(
      () => _service.readArchitectureMarkdown(overrideRoot: _projectRoot),
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
