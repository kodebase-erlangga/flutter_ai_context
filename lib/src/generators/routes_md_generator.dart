import '../scanner/detectors/route_detector.dart';
import '../shared/redaction.dart';
import 'markdown_header.dart';

/// Generates `.ai/routes.md` from detected routes.
class RoutesMdGenerator {
  String generate(List<DetectedRoute> routes) {
    final buffer = StringBuffer();
    buffer.write(MarkdownHeader.title('Routes'));

    if (routes.isEmpty) {
      buffer.writeln('No routes statically detected.');
      buffer.writeln();
      buffer.writeln(
          'Supported detectors: GoRouter, Navigator.pushNamed, context.go/push.');
      return Redaction.sanitize(buffer.toString());
    }

    buffer.writeln('| Path | Screen | Type | Confidence |');
    buffer.writeln('|------|--------|------|------------|');
    final sorted = [...routes]..sort((a, b) => a.path.compareTo(b.path));
    for (final route in sorted) {
      buffer.writeln(
        '| `${route.path}` | ${route.screenName ?? '—'} | ${route.routeType} | ${(route.confidence * 100).toStringAsFixed(0)}% |',
      );
    }

    buffer.writeln();
    buffer.writeln('## Evidence');
    buffer.writeln();
    for (final route in sorted) {
      buffer.writeln('- **${route.path}**: ${route.evidence.join(', ')}');
    }

    return Redaction.sanitize(buffer.toString());
  }
}
