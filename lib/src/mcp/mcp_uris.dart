/// MCP resource URI constants for flutter_ai_context.
abstract final class McpUris {
  static const agents = 'flutter-ai-context://agents';
  static const architecture = 'flutter-ai-context://architecture';
  static const graph = 'flutter-ai-context://graph';
  static const features = 'flutter-ai-context://features';
  static const contextTemplate = 'flutter-ai-context://context/{scope}';

  static bool isContextUri(String uri) {
    return uri.startsWith('flutter-ai-context://context/');
  }

  static String? scopeFromContextUri(String uri) {
    const prefix = 'flutter-ai-context://context/';
    if (!uri.startsWith(prefix)) return null;
    final scope = uri.substring(prefix.length);
    return scope.isEmpty ? null : scope;
  }
}
