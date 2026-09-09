import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}
