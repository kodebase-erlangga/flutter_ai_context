import 'package:flutter/foundation.dart';

import 'attendance_model.dart';
import 'attendance_service.dart';

class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider(this._service);

  final AttendanceService _service;
  AttendanceModel? _attendance;

  AttendanceModel? get attendance => _attendance;

  Future<void> load() async {
    _attendance = await _service.getAttendance();
    notifyListeners();
  }
}
