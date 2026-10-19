import '../models/attendance_record.dart';
import '../models/attendance_status.dart';
import 'api_client.dart';

abstract class AttendanceRepository {
  Future<SessionAttendance> sessionAttendance(String sessionId);
  Future<void> overrideStatus({
    required String sessionId,
    required String studentUserId,
    required AttendanceStatus status,
    required String reason,
  });
}

class ApiAttendanceRepository implements AttendanceRepository {
  ApiAttendanceRepository(this._api);

  final ApiClient _api;

  @override
  Future<SessionAttendance> sessionAttendance(String sessionId) async {
    final json = await _api.get('/sessions/$sessionId/attendance');
    return SessionAttendance.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<void> overrideStatus({
    required String sessionId,
    required String studentUserId,
    required AttendanceStatus status,
    required String reason,
  }) async {
    await _api.post(
      '/sessions/$sessionId/attendance/override',
      data: {
        'student_user_id': studentUserId,
        'status': status.name,
        'reason': reason,
      },
    );
  }
}
