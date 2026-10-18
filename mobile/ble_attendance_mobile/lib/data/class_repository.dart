import '../models/class_info.dart';
import 'api_client.dart';

abstract class ClassRepository {
  Future<List<ClassInfo>> myClasses();
  Future<ClassInfo> join(String joinCode);
}

class ApiClassRepository implements ClassRepository {
  ApiClassRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<ClassInfo>> myClasses() async {
    final json = await _api.get('/classes/mine') as List<dynamic>;
    return [
      for (final item in json) ClassInfo.fromJson(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<ClassInfo> join(String joinCode) async {
    final json = await _api.post(
      '/classes/join',
      data: {'join_code': joinCode},
    );
    return ClassInfo.fromJson(json as Map<String, dynamic>);
  }
}
