import '../core/formatters.dart';
import '../models/leave_request.dart';
import 'api_client.dart';

abstract class LeaveRepository {
  Future<List<LeaveRequest>> mine();
  Future<LeaveRequest> create({
    required String classId,
    required DateTime date,
    required String reason,
  });
}

class ApiLeaveRepository implements LeaveRepository {
  ApiLeaveRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<LeaveRequest>> mine() async {
    final json = await _api.get('/leave-requests/mine') as List<dynamic>;
    return [
      for (final item in json)
        LeaveRequest.fromJson(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<LeaveRequest> create({
    required String classId,
    required DateTime date,
    required String reason,
  }) async {
    final json = await _api.post(
      '/leave-requests',
      data: {'class_id': classId, 'date': toApiDate(date), 'reason': reason},
    );
    return LeaveRequest.fromJson(json as Map<String, dynamic>);
  }
}
