import '../models/attendance_history.dart';
import '../models/class_stats.dart';
import 'api_client.dart';

abstract class StatsRepository {
  Future<List<ClassStats>> stats();
  Future<List<AttendanceHistoryItem>> history(String classId);
}

class ApiStatsRepository implements StatsRepository {
  ApiStatsRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<ClassStats>> stats() async {
    final json = await _api.get('/me/attendance/stats') as List<dynamic>;
    return [
      for (final item in json)
        ClassStats.fromJson(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<List<AttendanceHistoryItem>> history(String classId) async {
    final json =
        await _api.get('/me/attendance', query: {'class_id': classId})
            as List<dynamic>;
    return [
      for (final item in json)
        AttendanceHistoryItem.fromJson(item as Map<String, dynamic>),
    ];
  }
}
