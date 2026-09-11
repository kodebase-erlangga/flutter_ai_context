import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:stream_channel/stream_channel.dart';

import '../cli/runner.dart';
import 'mcp_project_service.dart';
import 'mcp_uris.dart';
import 'project_root.dart';

/// MCP server exposing read-only flutter_ai_context project intelligence.
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
              'Use project_status to check FRESH/STALE, list_features for scopes, '
              'and get_context for token-budgeted feature context packs.',
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

  CallToolResult _errorResult(String message) {
    return CallToolResult(
      content: [Content.text(text: message)],
      isError: true,
    );
  }

  ReadResourceResult _textResourceResult(String uri, String text) {
    return ReadResourceResult(
      contents: [
        TextResourceContents(
          uri: uri,
          text: text,
          mimeType: 'text/markdown',
        ),
      ],
    );
  }
}
