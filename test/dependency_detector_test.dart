import 'package:flutter_ai_context/src/discovery/dependency_detector.dart';
import 'package:test/test.dart';

void main() {
  test('detects state management candidates from pubspec', () {
    const pubspec = '''
name: demo
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.0
  dio: ^5.0.0
  go_router: ^14.0.0
''';

    final detector = DependencyDetector();
    final deps = detector.detect(pubspec);
    final candidates = detector.stateManagementCandidates(deps);

    expect(candidates, contains('Provider'));
    expect(detector.detectNetworking(deps), 'Dio');
    expect(detector.detectRouting(deps), 'GoRouter');
  });
}
