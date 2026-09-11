import 'dart:convert';
import 'dart:io';

import '../analysis/analysis_pipeline.dart';
import '../cache/cache_manager.dart';
import '../cli/output/formatter.dart';
import '../config/config_loader.dart';
import '../config/models/project_config.dart';
import '../context/relevance_ranker.dart';
import '../context/scope_suggester.dart';
import '../discovery/project_discovery.dart';
import '../generators/context_pack_generator.dart';
import '../graph/project_graph.dart';
import '../graph/schema.dart';
import '../rules/findings.dart';
import '../shared/logger.dart';
import '../shared/paths.dart';
import '../config/models/mcp_settings.dart';
import 'graph_query.dart';
import 'mcp_get_context_result.dart';
import 'mcp_prompt_builder.dart';
import 'mcp_uris.dart';
import 'project_root.dart';

/// Project intelligence for MCP tools and resources.
class McpProjectService {
  McpProjectService({
    ConfigLoader? configLoader,
    ProjectDiscovery? discovery,
    ProjectRootResolver? rootResolver,
    AnalysisPipeline? pipeline,
    GraphQuery? graphQuery,
  })  : _configLoader = configLoader ?? ConfigLoader(),
        _discovery = discovery ?? ProjectDiscovery(),
        _rootResolver = rootResolver ?? const ProjectRootResolver(),
        _pipeline = pipeline ?? AnalysisPipeline(logger: Logger(level: LogLevel.quiet)),
        _graphQuery = graphQuery ?? const GraphQuery();

  static const maxFullGraphBytes = 256 * 1024;

  final ConfigLoader _configLoader;
  final ProjectDiscovery _discovery;
  final ProjectRootResolver _rootResolver;
  final AnalysisPipeline _pipeline;
  final GraphQuery _graphQuery;

  String resolveRoot({String? overrideRoot, String? cwd}) {
    return _rootResolver.resolve(overrideRoot: overrideRoot, cwd: cwd);
  }

  Map<String, Object?> projectStatus({
    String? overrideRoot,
    String? cwd,
  }) {
    final root = resolveRoot(overrideRoot: overrideRoot, cwd: cwd);
    final paths = ProjectPaths(root);

    if (!File(paths.configFile).existsSync()) {
      return {
        'initialized': false,
        'context': 'NOT_INITIALIZED',
        'message':
            'flutter_ai_context.yaml not found. Run `flutter_ai_context init`.',
        'projectRoot': root,
      };
    }

    final config = _configLoader.load(paths.configFile);
    final cache = CacheManager(paths);
    cache.load();
    cache.loadGraph();

    final metadata = cache.loadMetadata();
    final discovery = _discovery.discover(root, config);
    final changedCount = cache.countChangedFiles(root, discovery.dartFiles);

    if (metadata == null) {
      return {
        'initialized': false,
        'context': 'NOT_INITIALIZED',
        'message': 'No scan metadata. Run `flutter_ai_context init` or `scan`.',
        'projectRoot': root,
      };
    }

    if (cache.schemaMismatch) {
      return {
        'initialized': true,
        'project': discovery.projectName,
        'context': 'SCHEMA_MISMATCH',
        'graphSchema': graphSchemaVersion,
        'cachedSchema': cache.cachedSchemaVersion,
        'message': 'Run `flutter_ai_context scan` to rebuild the cache.',
        'projectRoot': root,
      };
    }

    final status = changedCount > 0 ? 'STALE' : 'FRESH';
    return {
      'initialized': true,
      'project': discovery.projectName,
      'context': status,
      'graphSchema': graphSchemaVersion,
      'filesIndexed': metadata.filesAnalyzed,
      'features': metadata.featureCount,
      'lastUpdate': metadata.lastScan.toIso8601String(),
      'changedFiles': changedCount,
      'projectRoot': root,
      if (status == 'STALE')
        'hint': 'Run tool `sync_context` to refresh context.',
    };
  }

  Future<Map<String, Object?>> syncContext({
    bool force = false,
    String? overrideRoot,
    String? cwd,
  }) async {
    final root = resolveRoot(overrideRoot: overrideRoot, cwd: cwd);
    final paths = ProjectPaths(root);
    final config = _configLoader.load(paths.configFile);
    final cache = CacheManager(paths);
    cache.load();

    final discovery = _discovery.discover(root, config);
    final changedBefore = cache.countChangedFiles(root, discovery.dartFiles);
    final schemaMismatch = cache.schemaMismatch;

    if (!force && changedBefore == 0 && !schemaMismatch) {
      return {
        'synced': false,
        'context': 'FRESH',
        'changedFiles': 0,
        'message': 'No changed files — context already up to date.',
      };
    }

    final result = await _pipeline.run(
      root: root,
      config: config,
      paths: paths,
      cache: cache,
      incremental: !schemaMismatch,
    );

    final changedAfter = cache.countChangedFiles(root, discovery.dartFiles);
    final status = changedAfter > 0 ? 'STALE' : 'FRESH';

    return {
      'synced': true,
      'context': status,
      'features': result.features.length,
      'filesSynced': changedBefore,
      'changedFilesRemaining': changedAfter,
      if (schemaMismatch) 'rebuilt': true,
    };
  }

  Future<Map<String, Object?>> runDoctor({
    String? overrideRoot,
    String? cwd,
  }) async {
    final root = resolveRoot(overrideRoot: overrideRoot, cwd: cwd);
    final paths = ProjectPaths(root);
    final config = _configLoader.load(paths.configFile);
    final cache = CacheManager(paths);
    final graph = cache.loadGraph();

    final result = graph == null
        ? await _pipeline.run(
            root: root,
            config: config,
            paths: paths,
            cache: cache,
          )
        : await _pipeline.run(
            root: root,
            config: config,
            paths: paths,
            cache: cache,
            incremental: true,
          );

    final report = result.doctorReport;
    return {
      'readinessScore': report.readinessScore,
      'observedArchitecture': report.observedArchitecture,
      'declaredArchitecture': report.declaredArchitecture,
      if (report.interpretation != null) 'interpretation': report.interpretation,
      'findings': report.findings
          .map(
            (finding) => {
              'severity': finding.severity.name,
              'message': finding.message,
              'file': finding.file,
              if (finding.rule != null) 'rule': finding.rule,
              if (finding.remediation != null) 'remediation': finding.remediation,
            },
          )
          .toList(),
      'reportText': OutputFormatter.doctorReport(report),
      'hasErrors': report.findings
          .any((finding) => finding.severity == FindingSeverity.error),
    };
  }

  Map<String, Object?> queryGraph({
    String? nodeType,
    String? feature,
    String? nameContains,
    int? limit,
    int? offset,
    String? overrideRoot,
    String? cwd,
  }) {
    final graph = _loadGraph(resolveRoot(overrideRoot: overrideRoot, cwd: cwd));
    try {
      return _graphQuery.query(
        graph,
        nodeType: nodeType,
        feature: feature,
        nameContains: nameContains,
        limit: limit ?? GraphQuery.defaultLimit,
        offset: offset ?? 0,
      );
    } on ArgumentError catch (e) {
      throw McpProjectException(e.message.toString());
    }
  }

  String readGraphJson({String? overrideRoot, String? cwd}) {
    final root = resolveRoot(overrideRoot: overrideRoot, cwd: cwd);
    final paths = ProjectPaths(root);
    final graphFile = File(paths.projectGraph);

    if (!graphFile.existsSync()) {
      throw McpProjectException(
        'project_graph.json not found. Run `flutter_ai_context scan` first.',
      );
    }

    final graph = _loadGraph(root);
    final fileBytes = graphFile.lengthSync();

    if (fileBytes > maxFullGraphBytes) {
      return encodeJson({
        'truncated': true,
        ..._graphQuery.summarize(graph, fileBytes: fileBytes),
      });
    }

    return graphFile.readAsStringSync();
  }

  List<Map<String, Object?>> listFeatures({
    String? overrideRoot,
    String? cwd,
  }) {
    final root = resolveRoot(overrideRoot: overrideRoot, cwd: cwd);
    final graph = _loadGraph(root);
    final features = graph.nodesByType(NodeType.feature).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return [
      for (final feature in features)
        {
          'name': feature.name,
          'members': graph
              .edgesFrom(feature.id)
              .where((edge) => edge.type == EdgeType.contains)
              .length,
        },
    ];
  }

  Future<McpGetContextResult> getContext({
    required String scope,
    bool? autoSync,
    bool? includeProjectBrief,
    String? overrideRoot,
    String? cwd,
  }) async {
    final root = resolveRoot(overrideRoot: overrideRoot, cwd: cwd);
    final paths = ProjectPaths(root);
    final config = _configLoader.load(paths.configFile);
    final settings = _resolveMcpSettings(config.mcp, autoSync, includeProjectBrief);

    final prelude = await _autoSyncIfNeeded(
      root: root,
      autoSync: settings.autoSyncOnGetContext,
    );

    final packMarkdown = _buildContextPack(
      root: root,
      paths: paths,
      config: config,
      scope: scope,
    );

    final markdown = _composeContextMarkdown(
      packMarkdown: packMarkdown,
      prelude: prelude,
      includeProjectBrief: settings.includeProjectBrief,
      agentsMarkdown: _tryReadAgents(paths),
    );

    final status = projectStatus(overrideRoot: root);
    return McpGetContextResult(
      markdown: markdown,
      contextStatus: status['context'] as String? ?? 'UNKNOWN',
      autoSynced: prelude?.synced ?? false,
      filesSynced: prelude?.filesSynced ?? 0,
    );
  }

  String getContextMarkdown({
    required String scope,
    String? overrideRoot,
    String? cwd,
  }) {
    final root = resolveRoot(overrideRoot: overrideRoot, cwd: cwd);
    final paths = ProjectPaths(root);
    final config = _configLoader.load(paths.configFile);
    return _buildContextPack(
      root: root,
      paths: paths,
      config: config,
      scope: scope,
    );
  }

  Future<String> readContextResource({
    required String uri,
    String? overrideRoot,
    String? cwd,
  }) async {
    final scope = McpUris.scopeFromContextUri(uri);
    if (scope == null) {
      throw McpProjectException('Invalid context resource URI: $uri');
    }

    final result = await getContext(
      scope: scope,
      overrideRoot: overrideRoot,
      cwd: cwd,
    );
    return result.markdown;
  }

  String readAgentsMarkdown({String? overrideRoot, String? cwd}) {
    final paths = ProjectPaths(resolveRoot(overrideRoot: overrideRoot, cwd: cwd));
    return _readTextFile(
      paths.agentsMd,
      fallbackMessage:
          'AGENTS.md not found. Run `flutter_ai_context init` first.',
    );
  }

  String readArchitectureMarkdown({String? overrideRoot, String? cwd}) {
    final paths = ProjectPaths(resolveRoot(overrideRoot: overrideRoot, cwd: cwd));
    return _readTextFile(
      paths.aiFile('architecture.md'),
      fallbackMessage:
          'architecture.md not found. Run `flutter_ai_context init` first.',
    );
  }

  String readFeaturesMarkdown({String? overrideRoot, String? cwd}) {
    final paths = ProjectPaths(resolveRoot(overrideRoot: overrideRoot, cwd: cwd));
    return _readTextFile(
      paths.aiFile('features.md'),
      fallbackMessage:
          'features.md not found. Run `flutter_ai_context init` or `sync` first.',
    );
  }

  Future<McpGetContextResult> buildFeatureContextPrompt({
    required String scope,
    String? overrideRoot,
    String? cwd,
  }) async {
    final context = await getContext(
      scope: scope,
      includeProjectBrief: false,
      overrideRoot: overrideRoot,
      cwd: cwd,
    );
    final agents = readAgentsMarkdown(overrideRoot: overrideRoot, cwd: cwd);
    return McpGetContextResult(
      markdown: McpPromptBuilder.combineFeaturePrompt(
        scope: scope,
        projectBrief: McpPromptBuilder.projectBriefFromAgents(agents),
        featureMarkdown: context.markdown,
      ),
      contextStatus: context.contextStatus,
      autoSynced: context.autoSynced,
      filesSynced: context.filesSynced,
    );
  }

  String encodeJson(Object? value) {
    return const JsonEncoder.withIndent('  ').convert(value);
  }

  ProjectGraph _loadGraph(String root) {
    final cache = CacheManager(ProjectPaths(root));
    final graph = cache.loadGraph();
    if (graph == null) {
      throw McpProjectException(
        'No project graph found. Run `flutter_ai_context scan` first.',
      );
    }
    return graph;
  }

  String _readTextFile(String path, {required String fallbackMessage}) {
    final file = File(path);
    if (!file.existsSync()) {
      throw McpProjectException(fallbackMessage);
    }
    return file.readAsStringSync();
  }

  String? _tryReadAgents(ProjectPaths paths) {
    final file = File(paths.agentsMd);
    if (!file.existsSync()) return null;
    return file.readAsStringSync();
  }

  McpSettings _resolveMcpSettings(
    McpSettings defaults,
    bool? autoSync,
    bool? includeProjectBrief,
  ) {
    return McpSettings(
      autoSyncOnGetContext: autoSync ?? defaults.autoSyncOnGetContext,
      includeProjectBrief: includeProjectBrief ?? defaults.includeProjectBrief,
    );
  }

  Future<_AutoSyncPrelude?> _autoSyncIfNeeded({
    required String root,
    required bool autoSync,
  }) async {
    if (!autoSync) return null;

    final status = projectStatus(overrideRoot: root);
    final context = status['context'] as String?;
    if (context == null ||
        context == 'NOT_INITIALIZED' ||
        context == 'FRESH') {
      return null;
    }

    final syncResult = await syncContext(
      force: context == 'SCHEMA_MISMATCH',
      overrideRoot: root,
    );

    return _AutoSyncPrelude(
      synced: syncResult['synced'] as bool? ?? false,
      filesSynced: syncResult['filesSynced'] as int? ??
          syncResult['changedFilesRemaining'] as int? ??
          0,
      contextBefore: context,
    );
  }

  String _buildContextPack({
    required String root,
    required ProjectPaths paths,
    required ProjectConfig config,
    required String scope,
  }) {
    final graph = _loadGraph(root);

    final ranker = RelevanceRanker();
    final result = ranker.rank(graph, scope);
    if (result.nodes.isEmpty) {
      final suggestions = ScopeSuggester().suggest(graph, scope);
      final hint = suggestions.isEmpty
          ? ''
          : ' Did you mean: ${suggestions.join(', ')}?';
      throw McpProjectException(
        'No context found for scope "$scope".$hint\n'
        'Use tool `list_features` to see available scopes.',
      );
    }

    final generator = ContextPackGenerator();
    final pack = generator.build(
      scope: scope,
      graph: graph,
      ranked: result.nodes,
      observedFlow: result.observedFlow,
      maxTokens: config.contextTokenBudget,
    );

    final outputPath = paths.contextFile(scope.toLowerCase());
    File(outputPath).parent.createSync(recursive: true);
    File(outputPath).writeAsStringSync(pack.content);

    return pack.content;
  }

  String _composeContextMarkdown({
    required String packMarkdown,
    required _AutoSyncPrelude? prelude,
    required bool includeProjectBrief,
    required String? agentsMarkdown,
  }) {
    final buffer = StringBuffer();

    if (prelude != null && prelude.synced) {
      buffer.writeln(
        '> **Context auto-synced** — ${prelude.filesSynced} file(s) updated.',
      );
      buffer.writeln();
    }

    if (includeProjectBrief && agentsMarkdown != null) {
      final brief = McpPromptBuilder.projectBriefFromAgents(agentsMarkdown);
      if (brief.isNotEmpty) {
        buffer.writeln('## Project Overview');
        buffer.writeln();
        buffer.writeln(brief);
        buffer.writeln();
        buffer.writeln('---');
        buffer.writeln();
      }
    }

    buffer.write(packMarkdown);
    return buffer.toString();
  }
}

class _AutoSyncPrelude {
  const _AutoSyncPrelude({
    required this.synced,
    required this.filesSynced,
    required this.contextBefore,
  });

  final bool synced;
  final int filesSynced;
  final String contextBefore;
}
