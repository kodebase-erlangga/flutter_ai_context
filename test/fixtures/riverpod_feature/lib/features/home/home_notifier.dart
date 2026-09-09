import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_repository.dart';

class HomeNotifier extends Notifier<String> {
  @override
  String build() => '';

  Future<void> load() async {
    state = await HomeRepository().fetchTitle();
  }
}

final homeNotifierProvider = NotifierProvider<HomeNotifier, String>(
  HomeNotifier.new,
);
