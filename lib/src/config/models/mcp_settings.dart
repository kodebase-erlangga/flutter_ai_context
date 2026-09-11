/// MCP server behavior configured in `flutter_ai_context.yaml`.
class McpSettings {
  /// Creates MCP settings with sensible defaults for AI clients.
  const McpSettings({
    this.autoSyncOnGetContext = true,
    this.includeProjectBrief = true,
  });

  /// When true, `get_context` runs incremental sync if context is STALE.
  final bool autoSyncOnGetContext;

  /// When true, feature context packs prepend a short project overview from AGENTS.md.
  final bool includeProjectBrief;

  /// Serializes to a YAML-compatible map.
  Map<String, dynamic> toYamlMap() => {
        'auto_sync_on_get_context': autoSyncOnGetContext,
        'include_project_brief': includeProjectBrief,
      };

  /// Parses MCP settings from a configuration map.
  factory McpSettings.fromYamlMap(Map<String, dynamic> map) {
    return McpSettings(
      autoSyncOnGetContext: map['auto_sync_on_get_context'] as bool? ?? true,
      includeProjectBrief: map['include_project_brief'] as bool? ?? true,
    );
  }
}
