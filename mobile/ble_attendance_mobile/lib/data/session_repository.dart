import '../core/api_exception.dart';
import '../models/session_info.dart';
import 'api_client.dart';

abstract class SessionRepository {
  /// Buổi học đang diễn ra của người dùng, hoặc null nếu không có.
  Future<SessionInfo?> activeSession();
  Future<void> finalize(String sessionId);

  // Dành cho giảng viên.
  Future<SessionInfo> startSession(String classId);
  Future<SessionInfo> endSession(String sessionId);
  Future<SessionInfo> openFinalization(String sessionId);
  Future<List<SessionInfo>> classSessions(String classId);
}

class ApiSessionRepository implements SessionRepository {
  ApiSessionRepository(this._api);

  final ApiClient _api;

  @override
  Future<SessionInfo?> activeSession() async {
    try {
      final json = await _api.get('/sessions/active');
      return SessionInfo.fromJson(json as Map<String, dynamic>);
    } on ApiException catch (error) {
      if (error.code == 'no_active_session') return null;
      rethrow;
    }
  }

  @override
  Future<void> finalize(String sessionId) async {
    await _api.post('/attendance/finalize', data: {'session_id': sessionId});
  }

  @override
  Future<SessionInfo> startSession(String classId) async =>
      SessionInfo.fromJson(
        await _api.post('/classes/$classId/sessions') as Map<String, dynamic>,
      );

  @override
  Future<SessionInfo> endSession(String sessionId) async =>
      SessionInfo.fromJson(
        await _api.post('/sessions/$sessionId/end') as Map<String, dynamic>,
      );

  @override
  Future<SessionInfo> openFinalization(String sessionId) async =>
      SessionInfo.fromJson(
        await _api.post('/sessions/$sessionId/open-finalization')
            as Map<String, dynamic>,
      );

  @override
  Future<List<SessionInfo>> classSessions(String classId) async {
    final json = await _api.get('/classes/$classId/sessions') as List<dynamic>;
    return [
      for (final item in json)
        SessionInfo.fromJson(item as Map<String, dynamic>),
    ];
  }
}
