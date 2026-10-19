import '../models/auth_user.dart';
import '../models/class_info.dart';
import '../models/course.dart';
import '../models/export_file.dart';
import '../models/import_report.dart';
import 'api_client.dart';
import 'file_chooser.dart';
import 'report_repository.dart' show filenameFromDisposition;

abstract class AdminRepository {
  Future<List<Course>> courses();
  Future<Course> createCourse({
    required String code,
    required String name,
    int? credits,
  });
  Future<Course> updateCourse(String id, {String? name, int? credits});
  Future<void> deleteCourse(String id);

  Future<List<ClassInfo>> allClasses();
  Future<ClassInfo> createClass({
    required String courseId,
    required String classCode,
    required String semester,
    String? teacherUserId,
    int maxAbsencePercent = 20,
    int rssiThreshold = -75,
  });
  Future<ClassInfo> updateClass(
    String id, {
    String? classCode,
    String? semester,
    int? maxAbsencePercent,
    int? rssiThreshold,
  });
  Future<void> deleteClass(String id);
  Future<ClassInfo> assignTeacher(String classId, String teacherUserId);

  Future<List<AuthUser>> teachers();
  Future<AuthUser> createTeacher({
    required String teacherId,
    required String fullName,
  });
  Future<void> resetPassword(String userId);

  Future<ImportReport> importStudents(
    String classId,
    PickedFile file, {
    required bool dryRun,
  });
  Future<ImportReport> importTeachers(PickedFile file, {required bool dryRun});
  Future<ImportReport> importClasses(PickedFile file, {required bool dryRun});
  Future<ExportFile> downloadTemplate(String kind);
}

class ApiAdminRepository implements AdminRepository {
  ApiAdminRepository(this._api);

  final ApiClient _api;

  Map<String, dynamic> _map(dynamic json) => json as Map<String, dynamic>;
  List<Map<String, dynamic>> _list(dynamic json) => [
    for (final item in json as List<dynamic>) item as Map<String, dynamic>,
  ];

  @override
  Future<List<Course>> courses() async => [
    for (final j in _list(await _api.get('/admin/courses'))) Course.fromJson(j),
  ];

  @override
  Future<Course> createCourse({
    required String code,
    required String name,
    int? credits,
  }) async => Course.fromJson(
    _map(
      await _api.post(
        '/admin/courses',
        data: {'code': code, 'name': name, 'credits': ?credits},
      ),
    ),
  );

  @override
  Future<Course> updateCourse(String id, {String? name, int? credits}) async =>
      Course.fromJson(
        _map(
          await _api.patch(
            '/admin/courses/$id',
            data: {'name': ?name, 'credits': ?credits},
          ),
        ),
      );

  @override
  Future<void> deleteCourse(String id) async {
    await _api.delete('/admin/courses/$id');
  }

  @override
  Future<List<ClassInfo>> allClasses() async => [
    for (final j in _list(await _api.get('/admin/classes')))
      ClassInfo.fromJson(j),
  ];

  @override
  Future<ClassInfo> createClass({
    required String courseId,
    required String classCode,
    required String semester,
    String? teacherUserId,
    int maxAbsencePercent = 20,
    int rssiThreshold = -75,
  }) async => ClassInfo.fromJson(
    _map(
      await _api.post(
        '/admin/classes',
        data: {
          'course_id': courseId,
          'class_code': classCode,
          'semester': semester,
          'teacher_user_id': ?teacherUserId,
          'max_absence_percent': maxAbsencePercent,
          'rssi_threshold': rssiThreshold,
        },
      ),
    ),
  );

  @override
  Future<ClassInfo> updateClass(
    String id, {
    String? classCode,
    String? semester,
    int? maxAbsencePercent,
    int? rssiThreshold,
  }) async => ClassInfo.fromJson(
    _map(
      await _api.patch(
        '/admin/classes/$id',
        data: {
          'class_code': ?classCode,
          'semester': ?semester,
          'max_absence_percent': ?maxAbsencePercent,
          'rssi_threshold': ?rssiThreshold,
        },
      ),
    ),
  );

  @override
  Future<void> deleteClass(String id) async {
    await _api.delete('/admin/classes/$id');
  }

  @override
  Future<ClassInfo> assignTeacher(String classId, String teacherUserId) async =>
      ClassInfo.fromJson(
        _map(
          await _api.post(
            '/admin/classes/$classId/assign-teacher',
            data: {'teacher_user_id': teacherUserId},
          ),
        ),
      );

  @override
  Future<List<AuthUser>> teachers() async => [
    for (final j in _list(await _api.get('/admin/teachers')))
      AuthUser.fromJson(j),
  ];

  @override
  Future<AuthUser> createTeacher({
    required String teacherId,
    required String fullName,
  }) async => AuthUser.fromJson(
    _map(
      await _api.post(
        '/admin/teachers',
        data: {'teacher_id': teacherId, 'full_name': fullName},
      ),
    ),
  );

  @override
  Future<void> resetPassword(String userId) async {
    await _api.post('/admin/users/$userId/reset-password');
  }

  Future<ImportReport> _import(
    String path,
    PickedFile file,
    bool dryRun,
  ) async => ImportReport.fromJson(
    _map(
      await _api.postFile(
        path,
        filename: file.name,
        bytes: file.bytes,
        query: {'dry_run': dryRun},
      ),
    ),
  );

  @override
  Future<ImportReport> importStudents(
    String classId,
    PickedFile file, {
    required bool dryRun,
  }) => _import('/admin/classes/$classId/import-students', file, dryRun);

  @override
  Future<ImportReport> importTeachers(
    PickedFile file, {
    required bool dryRun,
  }) => _import('/admin/imports/teachers', file, dryRun);

  @override
  Future<ImportReport> importClasses(PickedFile file, {required bool dryRun}) =>
      _import('/admin/imports/classes', file, dryRun);

  @override
  Future<ExportFile> downloadTemplate(String kind) async {
    final result = await _api.download('/admin/imports/templates/$kind');
    return ExportFile(
      filename: filenameFromDisposition(
        result.contentDisposition,
        '${kind}_template.csv',
      ),
      bytes: result.bytes,
    );
  }
}
