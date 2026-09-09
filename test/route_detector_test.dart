import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:flutter_ai_context/src/scanner/detectors/route_detector.dart';
import 'package:test/test.dart';

void main() {
  test('detects GoRoute paths and builder screens', () {
    const source = '''
import 'package:go_router/go_router.dart';
import 'home_screen.dart';

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/home',
      builder: (context, state) => HomeScreen(),
    ),
  ],
);
''';

    final unit = parseString(content: source).unit;
    final routes = RouteDetector().detect('lib/router.dart', unit);

    expect(routes.length, 1);
    expect(routes.first.path, '/home');
    expect(routes.first.routeType, 'go_router');
  });

  test('detects context.go navigation', () {
    const source = '''
void navigate(context) {
  context.go('/settings');
}
''';

    final unit = parseString(content: source).unit;
    final routes = RouteDetector().detect('lib/nav.dart', unit);

    expect(routes.map((r) => r.path), contains('/settings'));
  });
}
