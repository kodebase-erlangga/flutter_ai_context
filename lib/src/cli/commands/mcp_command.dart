import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/stdio.dart';

import '../../mcp/flutter_ai_context_mcp_server.dart';
import '../../mcp/mcp_project_service.dart';
import '../../mcp/project_root.dart';

/// Handles `flutter_ai_context mcp` — stdio MCP server for AI clients.
class McpCommand {
  McpCommand({
    McpProjectService? service,
    ProjectRootResolver? rootResolver,
  })  : _service = service ?? McpProjectService(),
        _rootResolver = rootResolver ?? const ProjectRootResolver();

  final McpProjectService _service;
  final ProjectRootResolver _rootResolver;

  Future<int> run({
    String? root,
    Stream<List<int>>? input,
    StreamSink<List<int>>? output,
  }) async {
    final projectRoot = _rootResolver.resolve(overrideRoot: root);

    final channel = stdioChannel(
      input: input ?? stdin,
      output: output ?? stdout,
    );

    final server = FlutterAiContextMcpServer(
      channel: channel,
      service: _service,
      projectRoot: projectRoot,
    );

    await server.done;
    return 0;
  }
}
