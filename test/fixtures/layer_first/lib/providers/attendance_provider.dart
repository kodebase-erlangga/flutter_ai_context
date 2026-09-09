import 'package:flutter/foundation.dart';

import '../services/attendance_service.dart';

class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider(this._service);

  final AttendanceService _service;

  Future<void> load() async {
    await _service.fetch();
    notifyListeners();
  }
}
