import 'package:flutter/foundation.dart';

import 'grade_service.dart';

class GradeProvider extends ChangeNotifier {
  GradeProvider(this._service);

  final GradeService _service;

  Future<void> load() async {
    await _service.getGrades();
    notifyListeners();
  }
}
