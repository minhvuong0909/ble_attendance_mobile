import '../models/class_info.dart';
import '../models/student_info.dart';
import 'api_client.dart';

abstract class ClassRepository {
  Future<List<ClassInfo>> myClasses();
  Future<ClassInfo> join(String joinCode);
  Future<List<StudentInfo>> classStudents(String classId);
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

  @override
  Future<List<StudentInfo>> classStudents(String classId) async {
    final json = await _api.get('/classes/$classId/students') as List<dynamic>;
    return [
      for (final item in json)
        StudentInfo.fromJson(item as Map<String, dynamic>),
    ];
  }
}
