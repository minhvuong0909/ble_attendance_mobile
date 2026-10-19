import 'dart:convert';

import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/data/admin_repository.dart';
import 'package:ble_attendance_mobile/data/api_client.dart';
import 'package:ble_attendance_mobile/data/file_chooser.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_adapter.dart';
import 'helpers/memory_token_store.dart';

const _course = {
  'id': 'k1',
  'code': 'PRM393',
  'name': 'Lập trình di động',
  'credits': 3,
};
const _class = {
  'id': 'c1',
  'course_id': 'k1',
  'course_code': 'PRM393',
  'course_name': 'Lập trình di động',
  'class_code': 'SE1901',
  'semester': 'FA26',
  'teacher_user_id': null,
  'teacher_name': null,
  'join_code': 'ABC123',
  'max_absence_percent': 20,
  'rssi_threshold': -75,
  'student_count': 0,
};
const _teacher = {
  'id': 't1',
  'full_name': 'Co Lan',
  'role': 'teacher',
  'student_id': null,
  'teacher_id': 'T001',
  'must_change_password': true,
};
const _report = {
  'kind': 'students',
  'dry_run': true,
  'committed': false,
  'total': 1,
  'created': 1,
  'skipped': 0,
  'errors': 0,
  'rows': [
    {'row': 2, 'status': 'created', 'message': 'ok'},
  ],
};

({AdminRepository repo, FakeAdapter adapter}) _setup(FakeHandler handler) {
  final adapter = FakeAdapter(handler);
  final client = ApiClient(
    store: MemoryTokenStore(),
    dio: Dio()..httpClientAdapter = adapter,
    defaultBaseUrl: 'http://x',
  );
  return (repo: ApiAdminRepository(client), adapter: adapter);
}

Map<String, dynamic> _body(RequestOptions r) =>
    jsonDecode(jsonEncode(r.data)) as Map<String, dynamic>;

void main() {
  test('courses CRUD', () async {
    final list = _setup((_) async => jsonBody([_course]));
    expect((await list.repo.courses()).single.code, 'PRM393');
    expect(list.adapter.requests.single.path, '/admin/courses');

    final create = _setup((_) async => jsonBody(_course, status: 201));
    await create.repo.createCourse(
      code: 'PRM393',
      name: 'Lập trình di động',
      credits: 3,
    );
    expect(create.adapter.requests.single.method, 'POST');
    expect(_body(create.adapter.requests.single), {
      'code': 'PRM393',
      'name': 'Lập trình di động',
      'credits': 3,
    });

    final update = _setup((_) async => jsonBody(_course));
    await update.repo.updateCourse('k1', name: 'Mới');
    expect(update.adapter.requests.single.method, 'PATCH');
    expect(update.adapter.requests.single.path, '/admin/courses/k1');
    expect(_body(update.adapter.requests.single), {'name': 'Mới'});

    final delete = _setup((_) async => ResponseBody.fromString('', 204));
    await delete.repo.deleteCourse('k1');
    expect(delete.adapter.requests.single.method, 'DELETE');
    expect(delete.adapter.requests.single.path, '/admin/courses/k1');
  });

  test('createCourse omits credits when null', () async {
    final s = _setup((_) async => jsonBody(_course, status: 201));
    await s.repo.createCourse(code: 'X1', name: 'Y1');
    expect(_body(s.adapter.requests.single), {'code': 'X1', 'name': 'Y1'});
  });

  test('classes CRUD and teacher assignment', () async {
    final all = _setup((_) async => jsonBody([_class]));
    expect((await all.repo.allClasses()).single.joinCode, 'ABC123');
    expect(all.adapter.requests.single.path, '/admin/classes');

    final create = _setup((_) async => jsonBody(_class, status: 201));
    await create.repo.createClass(
      courseId: 'k1',
      classCode: 'SE1901',
      semester: 'FA26',
    );
    expect(_body(create.adapter.requests.single), {
      'course_id': 'k1',
      'class_code': 'SE1901',
      'semester': 'FA26',
      'max_absence_percent': 20,
      'rssi_threshold': -75,
    });

    final withTeacher = _setup((_) async => jsonBody(_class, status: 201));
    await withTeacher.repo.createClass(
      courseId: 'k1',
      classCode: 'SE1901',
      semester: 'FA26',
      teacherUserId: 't1',
      maxAbsencePercent: 25,
      rssiThreshold: -70,
    );
    expect(_body(withTeacher.adapter.requests.single)['teacher_user_id'], 't1');
    expect(
      _body(withTeacher.adapter.requests.single)['max_absence_percent'],
      25,
    );

    final update = _setup((_) async => jsonBody(_class));
    await update.repo.updateClass('c1', rssiThreshold: -70);
    expect(update.adapter.requests.single.method, 'PATCH');
    expect(_body(update.adapter.requests.single), {'rssi_threshold': -70});

    final delete = _setup((_) async => ResponseBody.fromString('', 204));
    await delete.repo.deleteClass('c1');
    expect(delete.adapter.requests.single.method, 'DELETE');

    final assign = _setup((_) async => jsonBody(_class));
    await assign.repo.assignTeacher('c1', 't1');
    expect(
      assign.adapter.requests.single.path,
      '/admin/classes/c1/assign-teacher',
    );
    expect(_body(assign.adapter.requests.single), {'teacher_user_id': 't1'});
  });

  test('teachers and password reset', () async {
    final list = _setup((_) async => jsonBody([_teacher]));
    expect((await list.repo.teachers()).single.teacherId, 'T001');
    expect(list.adapter.requests.single.path, '/admin/teachers');

    final create = _setup((_) async => jsonBody(_teacher, status: 201));
    await create.repo.createTeacher(teacherId: 'T001', fullName: 'Co Lan');
    expect(_body(create.adapter.requests.single), {
      'teacher_id': 'T001',
      'full_name': 'Co Lan',
    });

    final reset = _setup((_) async => jsonBody({'message': 'ok'}));
    await reset.repo.resetPassword('u9');
    expect(reset.adapter.requests.single.method, 'POST');
    expect(
      reset.adapter.requests.single.path,
      '/admin/users/u9/reset-password',
    );
  });

  test('imports upload a multipart file with the dry_run flag', () async {
    final s = _setup((_) async => jsonBody(_report));
    final file = PickedFile(
      name: 'sv.csv',
      bytes: utf8.encode('student_id,full_name\n'),
    );

    final preview = await s.repo.importStudents('c1', file, dryRun: true);
    expect(preview.canCommit, isTrue);
    final request = s.adapter.requests.single;
    expect(request.path, '/admin/classes/c1/import-students');
    expect(request.queryParameters, {'dry_run': true});
    final form = request.data as FormData;
    expect(form.files.single.key, 'file');
    expect(form.files.single.value.filename, 'sv.csv');

    final t = _setup((_) async => jsonBody(_report));
    await t.repo.importTeachers(file, dryRun: false);
    expect(t.adapter.requests.single.path, '/admin/imports/teachers');
    expect(t.adapter.requests.single.queryParameters, {'dry_run': false});

    final c = _setup((_) async => jsonBody(_report));
    await c.repo.importClasses(file, dryRun: true);
    expect(c.adapter.requests.single.path, '/admin/imports/classes');
  });

  test('an import error from the server becomes an ApiException', () async {
    final s = _setup(
      (_) async => jsonBody({
        'detail': 'Thiếu cột: student_id',
        'code': 'missing_columns',
      }, status: 422),
    );
    await expectLater(
      s.repo.importStudents(
        'c1',
        PickedFile(name: 'a.csv', bytes: const [1]),
        dryRun: true,
      ),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'missing_columns'),
      ),
    );
  });

  test('downloadTemplate returns the server file name and bytes', () async {
    final s = _setup(
      (_) async => ResponseBody.fromBytes(
        [1, 2, 3],
        200,
        headers: {
          'content-disposition': [
            'attachment; filename="students_template.csv"',
          ],
          Headers.contentTypeHeader: ['text/csv'],
        },
      ),
    );
    final file = await s.repo.downloadTemplate('students');
    expect(file.filename, 'students_template.csv');
    expect(file.bytes, [1, 2, 3]);
    expect(s.adapter.requests.single.path, '/admin/imports/templates/students');
  });
}
