import '../../core/api_client.dart';
import 'attendance_model.dart';

class AttendanceService {
  AttendanceService(this._apiClient);

  final ApiClient _apiClient;

  Future<AttendanceModel> getAttendance() async {
    final data = await _apiClient.get('/attendance');
    return AttendanceModel.fromJson(data);
  }
}

// touched

// touched
