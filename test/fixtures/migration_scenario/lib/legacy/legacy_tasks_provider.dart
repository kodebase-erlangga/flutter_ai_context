import 'package:flutter/foundation.dart';

class LegacyTasksProvider extends ChangeNotifier {
  final tasks = <String>[];

  void addTask(String task) {
    tasks.add(task);
    notifyListeners();
  }
}
