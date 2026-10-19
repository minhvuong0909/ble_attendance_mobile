import 'dart:convert';

import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/data/api_client.dart';
import 'package:ble_attendance_mobile/data/attendance_repository.dart';
import 'package:ble_attendance_mobile/data/class_repository.dart';
import 'package:ble_attendance_mobile/data/detection_repository.dart';
import 'package:ble_attendance_mobile/data/leave_repository.dart';
import 'package:ble_attendance_mobile/data/report_repository.dart';
import 'package:ble_attendance_mobile/data/session_repository.dart';
import 'package:ble_attendance_mobile/models/attendance_status.dart';
import 'package:ble_attendance_mobile/models/leave_request.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_adapter.dart';
import 'helpers/memory_token_store.dart';

const _session = {
  'id': 's1',
  'class_id': 'c1',
  'class_code': 'SE1901',
  'course_code': 'PRM393',
  'course_name': 'Lập trình di động',
  'teacher_user_id': 't1',
  'beacon_code': 'abcd1234',
  'starts_at': '2026-10-18T03:00:00Z',
  'ends_at': null,
  'is_active': true,
  'finalization_open': false,
  'beacon_secret': null,
};

const _leave = {
  'id': 4,
  'student_user_id': 'u1',
  'student_id': '25CE099',
  'student_name': 'An',
  'class_id': 'c1',
  'course_code': 'PRM393',
  'class_code': 'SE1901',
  'date': '2026-10-18',
  'reason': 'Bị ốm',
  'status': 'approved',
  'created_at': '2026-10-17T10:00:00Z',
  'reviewed_at': '2026-10-17T11:00:00Z',
  'review_note': null,
};

({ApiClient client, FakeAdapter adapter}) _setup(FakeHandler handler) {
  final adapter = FakeAdapter(handler);
  final client = ApiClient(
    store: MemoryTokenStore(),
    dio: Dio()..httpClientAdapter = adapter,
    defaultBaseUrl: 'http://x',
  );
  return (client: client, adapter: adapter);
}

Map<String, dynamic> _body(RequestOptions r) =>
    jsonDecode(jsonEncode(r.data)) as Map<String, dynamic>;

ResponseBody _bytes(List<int> data, {String? disposition, int status = 200}) =>
    ResponseBody.fromBytes(
      data,
      status,
      headers: {
        if (disposition != null) 'content-disposition': [disposition],
        Headers.contentTypeHeader: ['application/octet-stream'],
      },
    );

void main() {
  filenameSafetyTests();
  detectionTests();
  test('ClassRepository.classStudents', () async {
    final s = _setup(
      (_) async => jsonBody([
        {'id': 'u1', 'student_id': '25CE099', 'full_name': 'An'},
      ]),
    );
    final students = await ApiClassRepository(s.client).classStudents('c1');
    expect(students.single.fullName, 'An');
    expect(s.adapter.requests.single.path, '/classes/c1/students');
  });

  test('SessionRepository teacher actions', () async {
    final start = _setup((_) async => jsonBody(_session, status: 201));
    expect(
      (await ApiSessionRepository(start.client).startSession('c1')).id,
      's1',
    );
    expect(start.adapter.requests.single.method, 'POST');
    expect(start.adapter.requests.single.path, '/classes/c1/sessions');

    final end = _setup((_) async => jsonBody(_session));
    await ApiSessionRepository(end.client).endSession('s1');
    expect(end.adapter.requests.single.path, '/sessions/s1/end');

    final open = _setup((_) async => jsonBody(_session));
    await ApiSessionRepository(open.client).openFinalization('s1');
    expect(open.adapter.requests.single.path, '/sessions/s1/open-finalization');

    final history = _setup((_) async => jsonBody([_session, _session]));
    expect(
      await ApiSessionRepository(history.client).classSessions('c1'),
      hasLength(2),
    );
    expect(history.adapter.requests.single.path, '/classes/c1/sessions');
  });

  test('AttendanceRepository.sessionAttendance and override', () async {
    final list = _setup(
      (_) async => jsonBody({
        'session_id': 's1',
        'class_id': 'c1',
        'total_students': 0,
        'present_students': 0,
        'records': [],
      }),
    );
    final result = await ApiAttendanceRepository(
      list.client,
    ).sessionAttendance('s1');
    expect(result.records, isEmpty);
    expect(list.adapter.requests.single.path, '/sessions/s1/attendance');

    final override = _setup(
      (_) async => jsonBody({
        'student_user_id': 'u1',
        'status': 'excused',
        'overridden_by': 't1',
        'overridden_at': '2026-10-18T03:00:00Z',
        'override_reason': 'Có giấy phép',
      }),
    );
    await ApiAttendanceRepository(override.client).overrideStatus(
      sessionId: 's1',
      studentUserId: 'u1',
      status: AttendanceStatus.excused,
      reason: 'Có giấy phép',
    );
    expect(
      override.adapter.requests.single.path,
      '/sessions/s1/attendance/override',
    );
    expect(_body(override.adapter.requests.single), {
      'student_user_id': 'u1',
      'status': 'excused',
      'reason': 'Có giấy phép',
    });
  });

  test('ReportRepository.classReport', () async {
    final s = _setup(
      (_) async => jsonBody({
        'class_id': 'c1',
        'course_code': 'PRM393',
        'course_name': 'Lập trình di động',
        'class_code': 'SE1901',
        'semester': 'FA26',
        'sessions': [],
        'students': [],
        'average_attendance_percent': 100.0,
      }),
    );
    final report = await ApiReportRepository(s.client).classReport('c1');
    expect(report.students, isEmpty);
    expect(s.adapter.requests.single.path, '/classes/c1/report');
  });

  test(
    'ReportRepository exports return bytes and the server file name',
    () async {
      final data = [80, 75, 3, 4];
      final cls = _setup(
        (_) async => _bytes(
          data,
          disposition:
              'attachment; filename="attendance_PRM393_SE1901_FA26.xlsx"',
        ),
      );
      final file = await ApiReportRepository(cls.client).exportClass('c1');
      expect(file.filename, 'attendance_PRM393_SE1901_FA26.xlsx');
      expect(file.bytes, data);
      expect(cls.adapter.requests.single.path, '/classes/c1/report/export');

      final session = _setup((_) async => _bytes(data));
      final fallback = await ApiReportRepository(
        session.client,
      ).exportSession('s1');
      expect(fallback.filename, 'attendance.xlsx');
      expect(session.adapter.requests.single.path, '/sessions/s1/export');
    },
  );

  test(
    'a failed export becomes an ApiException with the server code',
    () async {
      final s = _setup(
        (_) async => ResponseBody.fromString(
          jsonEncode({
            'detail': 'Không tìm thấy lớp',
            'code': 'class_not_found',
          }),
          404,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      await expectLater(
        ApiReportRepository(s.client).exportClass('c1'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'class_not_found'),
        ),
      );
    },
  );

  test(
    'filenameFromDisposition handles quotes, missing header and extra params',
    () {
      expect(
        filenameFromDisposition('attachment; filename="a b.xlsx"', 'x'),
        'a b.xlsx',
      );
      expect(
        filenameFromDisposition('attachment; filename=plain.xlsx; size=3', 'x'),
        'plain.xlsx',
      );
      expect(filenameFromDisposition(null, 'x.xlsx'), 'x.xlsx');
      expect(filenameFromDisposition('inline', 'x.xlsx'), 'x.xlsx');
    },
  );

  test('LeaveRepository.classRequests and review', () async {
    final list = _setup((_) async => jsonBody([_leave]));
    final repo = ApiLeaveRepository(list.client);
    expect(
      (await repo.classRequests('c1', status: LeaveStatus.pending)).single.id,
      4,
    );
    expect(list.adapter.requests.single.path, '/classes/c1/leave-requests');
    expect(list.adapter.requests.single.queryParameters, {'status': 'pending'});

    final all = _setup((_) async => jsonBody([]));
    await ApiLeaveRepository(all.client).classRequests('c1');
    expect(all.adapter.requests.single.queryParameters, isEmpty);

    final review = _setup((_) async => jsonBody(_leave));
    await ApiLeaveRepository(
      review.client,
    ).review(leaveId: 4, decision: 'approved', note: 'OK');
    expect(review.adapter.requests.single.path, '/leave-requests/4/review');
    expect(_body(review.adapter.requests.single), {
      'decision': 'approved',
      'note': 'OK',
    });
  });
}

void detectionTests() {
  test(
    'DetectionRepository.postBatch sends entries and parses the result',
    () async {
      final s = _setup((_) async => jsonBody({'recorded': 2, 'rejected': 1}));
      final result = await ApiDetectionRepository(s.client).postBatch([
        DetectionEntry(
          sessionId: 's1',
          studentId: '25CE099',
          bucket: 59743080,
          tag: 'deadbeef',
          rssi: -60,
          observedAt: DateTime.utc(2026, 10, 18, 3),
        ),
      ]);
      expect(result.recorded, 2);
      expect(result.rejected, 1);
      final request = s.adapter.requests.single;
      expect(request.path, '/detections/batch');
      expect(_body(request)['detections'], [
        {
          'session_id': 's1',
          'student_identifier': '25CE099',
          'bucket': 59743080,
          'tag': 'deadbeef',
          'rssi': -60,
          'observed_at': '2026-10-18T03:00:00.000Z',
        },
      ]);
    },
  );
}

void filenameSafetyTests() {
  test('filenameFromDisposition never returns a path', () {
    expect(
      filenameFromDisposition('attachment; filename="../../etc/a.xlsx"', 'x'),
      'a.xlsx',
    );
    expect(
      filenameFromDisposition(r'attachment; filename="C:\tmp\b.xlsx"', 'x'),
      'b.xlsx',
    );
    expect(
      filenameFromDisposition('attachment; filename=".."', 'fb.xlsx'),
      'fb.xlsx',
    );
  });
}
