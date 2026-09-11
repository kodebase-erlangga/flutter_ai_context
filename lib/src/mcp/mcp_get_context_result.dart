/// Result of MCP `get_context` with optional auto-sync metadata.
class McpGetContextResult {
  const McpGetContextResult({
    required this.markdown,
    required this.contextStatus,
    this.autoSynced = false,
    this.filesSynced = 0,
  });

  /// Full Markdown body for the agent.
  final String markdown;

  /// Context freshness after any auto-sync (`FRESH`, `STALE`, etc.).
  final String contextStatus;

  /// Whether an incremental sync ran before building the pack.
  final bool autoSynced;

  /// Files updated during auto-sync (0 when skipped).
  final int filesSynced;

  Map<String, Object?> toJson() => {
        'contextStatus': contextStatus,
        'autoSynced': autoSynced,
        'filesSynced': filesSynced,
        'markdown': markdown,
      };
}
