/// Configuration model for `flutter_ai_context.yaml`.
///
/// Loaded by the CLI scanner and used to override auto-detected
/// architecture settings, scan paths, and context output options.
class ProjectConfig {
  /// Creates a project configuration with sensible defaults.
  const ProjectConfig({
    this.projectName,
    this.stateManagement = 'auto',
    this.routing = 'auto',
    this.networking = 'auto',
    this.scanPaths = const ['lib', 'test', 'integration_test'],
    this.ignorePatterns = const [
      'build/**',
      '.dart_tool/**',
      '**/*.g.dart',
      '**/*.freezed.dart',
    ],
    this.contextOutput = '.ai',
    this.generateAgentsMd = true,
    this.generateCursorRule = true,
    this.contextTokenBudget = 2000,
    this.directHttpFromUi = 'auto',
    this.preferredScreenSuffix,
    this.preferredProviderSuffix,
    this.forbiddenStateManagement = const [],
  });

  /// Display name written to generated context files.
  final String? projectName;

  /// Declared state management (`auto`, `provider`, `riverpod`, etc.).
  final String stateManagement;

  /// Declared routing approach (`auto`, `go_router`, etc.).
  final String routing;

  /// Declared networking library (`auto`, `dio`, etc.).
  final String networking;

  /// Directories scanned for Dart sources.
  final List<String> scanPaths;

  /// Glob patterns excluded from scanning.
  final List<String> ignorePatterns;

  /// Output directory for generated AI context (default `.ai`).
  final String contextOutput;

  /// Whether to emit `AGENTS.md` at the project root.
  final bool generateAgentsMd;

  /// Whether to emit `.cursor/rules/flutter-ai-context.mdc` on init/scan.
  final bool generateCursorRule;

  /// Token budget for per-feature context packs.
  final int contextTokenBudget;

  /// Rule for HTTP calls from UI (`auto`, `forbid`, `allow`).
  final String directHttpFromUi;

  /// Expected suffix for screen classes (e.g. `Screen`).
  final String? preferredScreenSuffix;

  /// Expected suffix for provider classes (e.g. `Provider`).
  final String? preferredProviderSuffix;

  /// State-management libraries flagged as forbidden.
  final List<String> forbiddenStateManagement;

  /// Serializes this config to a YAML-compatible map.
  Map<String, dynamic> toYamlMap() {
    return {
      'project': {'name': projectName ?? 'my_flutter_app'},
      'architecture': {
        'state_management': stateManagement,
        'routing': routing,
        'networking': networking,
      },
      'scan': {
        'paths': scanPaths,
        'ignore': ignorePatterns,
      },
      'context': {
        'output': contextOutput,
        'generate_agents_md': generateAgentsMd,
        'generate_cursor_rule': generateCursorRule,
        'token_budget': contextTokenBudget,
      },
      'rules': {
        'architecture': {'direct_http_from_ui': directHttpFromUi},
        if (preferredScreenSuffix != null)
          'naming': {
            'screen_suffix': preferredScreenSuffix,
            if (preferredProviderSuffix != null)
              'provider_suffix': preferredProviderSuffix,
          },
        if (forbiddenStateManagement.isNotEmpty)
          'state_management': {'forbidden': forbiddenStateManagement},
      },
    };
  }

  /// Parses a configuration map (from `package:yaml`).
  factory ProjectConfig.fromYamlMap(Map<dynamic, dynamic> map) {
    final project = _asMap(map['project']);
    final architecture = _asMap(map['architecture']);
    final scan = _asMap(map['scan']);
    final context = _asMap(map['context']);
    final rules = _asMap(map['rules']);
    final archRules = _asMap(rules['architecture']);
    final namingRules = _asMap(rules['naming']);
    final smRules = _asMap(rules['state_management']);

    return ProjectConfig(
      projectName: project['name'] as String?,
      stateManagement: architecture['state_management'] as String? ?? 'auto',
      routing: architecture['routing'] as String? ?? 'auto',
      networking: architecture['networking'] as String? ?? 'auto',
      scanPaths: _asStringList(scan['paths']) ??
          const ['lib', 'test', 'integration_test'],
      ignorePatterns: _asStringList(scan['ignore']) ??
          const [
            'build/**',
            '.dart_tool/**',
            '**/*.g.dart',
            '**/*.freezed.dart',
          ],
      contextOutput: context['output'] as String? ?? '.ai',
      generateAgentsMd: context['generate_agents_md'] as bool? ?? true,
      generateCursorRule: context['generate_cursor_rule'] as bool? ?? true,
      contextTokenBudget: _asInt(context['token_budget']) ?? 2000,
      directHttpFromUi: archRules['direct_http_from_ui'] as String? ?? 'auto',
      preferredScreenSuffix: namingRules['screen_suffix'] as String?,
      preferredProviderSuffix: namingRules['provider_suffix'] as String?,
      forbiddenStateManagement: _asStringList(smRules['forbidden']) ?? const [],
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return {};
  }

  static List<String>? _asStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
