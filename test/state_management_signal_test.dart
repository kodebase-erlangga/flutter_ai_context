import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:flutter_ai_context/src/scanner/detectors/state_management_signal_detector.dart';
import 'package:test/test.dart';

void main() {
  test('detects Riverpod ref.watch signals', () {
    const source = '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  Widget build(context, WidgetRef ref) {
    ref.watch(homeProvider);
    return Container();
  }
}
''';

    final unit = parseString(content: source).unit;
    final signals = StateManagementSignalDetector().detect(
      unit,
      ['package:flutter_riverpod/flutter_riverpod.dart'],
    );

    expect(signals.riverpod, greaterThan(0));
    expect(signals.evidence.any((e) => e.contains('ref.watch')), isTrue);
  });

  test('detects GetX controller and Obx', () {
    const source = '''
import 'package:get/get.dart';

class ProfileController extends GetxController {
  final name = 'x'.obs;
}

void build() {
  Get.put(ProfileController());
  Obx(() => Text(''));
}
''';

    final unit = parseString(content: source).unit;
    final signals = StateManagementSignalDetector().detect(
      unit,
      ['package:get/get.dart'],
    );

    expect(signals.getx, greaterThan(0));
  });
}
