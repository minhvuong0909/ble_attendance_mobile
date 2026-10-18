import '../core/api_exception.dart';
import '../models/session_info.dart';
import 'api_client.dart';

abstract class SessionRepository {
  /// Buổi học đang diễn ra của người dùng, hoặc null nếu không có.
  Future<SessionInfo?> activeSession();
  Future<void> finalize(String sessionId);
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
}
