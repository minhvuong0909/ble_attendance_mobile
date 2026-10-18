import 'dart:convert';

import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/data/api_client.dart';
import 'package:ble_attendance_mobile/data/class_repository.dart';
import 'package:ble_attendance_mobile/data/leave_repository.dart';
import 'package:ble_attendance_mobile/data/notification_repository.dart';
import 'package:ble_attendance_mobile/data/session_repository.dart';
import 'package:ble_attendance_mobile/data/stats_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_adapter.dart';
import 'helpers/memory_token_store.dart';

const _classJson = {
  'id': 'c1',
  'course_id': 'k1',
  'course_code': 'PRM393',
  'course_name': 'Lập trình di động',
  'class_code': 'SE1901',
  'semester': 'FA26',
  'teacher_user_id': 't1',
  'teacher_name': 'Co Lan',
  'join_code': null,
  'max_absence_percent': 20,
  'rssi_threshold': -75,
  'student_count': 3,
};

const _sessionJson = {
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
  'finalization_open': true,
  'beacon_secret': 'secret',
};

const _leaveJson = {
  'id': 1,
  'student_user_id': 'u1',
  'student_id': '25CE099',
  'student_name': 'An',
  'class_id': 'c1',
  'course_code': 'PRM393',
  'class_code': 'SE1901',
  'date': '2026-10-18',
  'reason': 'Bị ốm',
  'status': 'pending',
  'created_at': '2026-10-17T10:00:00Z',
  'reviewed_at': null,
  'review_note': null,
};

const _notificationJson = {
  'id': 1,
  'type': 'info',
  'title': 'Tiêu đề',
  'body': 'Nội dung',
  'ref_id': null,
  'is_read': false,
  'created_at': '2026-10-18T03:00:00Z',
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

void main() {
  test('ClassRepository.myClasses and join', () async {
    final s = _setup((_) async => jsonBody([_classJson]));
    final repo = ApiClassRepository(s.client);
    final classes = await repo.myClasses();
    expect(classes.single.title, 'PRM393 · SE1901');
    expect(s.adapter.requests.single.method, 'GET');
    expect(s.adapter.requests.single.path, '/classes/mine');

    final joined = _setup((_) async => jsonBody(_classJson));
    final result = await ApiClassRepository(joined.client).join('ABC123');
    expect(result.id, 'c1');
    expect(joined.adapter.requests.single.path, '/classes/join');
    expect(_body(joined.adapter.requests.single), {'join_code': 'ABC123'});
  });

  test('SessionRepository.activeSession returns the session or null', () async {
    final found = _setup((_) async => jsonBody(_sessionJson));
    expect(
      (await ApiSessionRepository(found.client).activeSession())!.id,
      's1',
    );
    expect(found.adapter.requests.single.path, '/sessions/active');

    final none = _setup(
      (_) async => jsonBody({
        'detail': 'Không có',
        'code': 'no_active_session',
      }, status: 404),
    );
    expect(await ApiSessionRepository(none.client).activeSession(), isNull);

    final other = _setup(
      (_) async => jsonBody({
        'detail': 'Không có',
        'code': 'class_not_found',
      }, status: 404),
    );
    await expectLater(
      ApiSessionRepository(other.client).activeSession(),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'class_not_found'),
      ),
    );
  });

  test('SessionRepository.finalize posts the session id', () async {
    final s = _setup(
      (_) async => jsonBody({
        'session_id': 's1',
        'finalized': true,
        'finalized_at': null,
      }),
    );
    await ApiSessionRepository(s.client).finalize('s1');
    expect(s.adapter.requests.single.path, '/attendance/finalize');
    expect(_body(s.adapter.requests.single), {'session_id': 's1'});
  });

  test('SessionRepository.finalize surfaces server errors', () async {
    final s = _setup(
      (_) async => jsonBody({
        'detail': 'Chưa phát hiện bạn',
        'code': 'not_in_range',
      }, status: 409),
    );
    await expectLater(
      ApiSessionRepository(s.client).finalize('s1'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'not_in_range'),
      ),
    );
  });

  test('StatsRepository.stats and history', () async {
    final stats = _setup(
      (_) async => jsonBody([
        {
          'class_id': 'c1',
          'course_code': 'PRM393',
          'course_name': 'Lập trình di động',
          'class_code': 'SE1901',
          'semester': 'FA26',
          'total_sessions': 3,
          'present': 2,
          'absent': 1,
          'excused': 0,
          'attendance_percent': 66.7,
          'absent_percent': 33.3,
          'max_absence_percent': 20,
          'warning': true,
        },
      ]),
    );
    expect(
      (await ApiStatsRepository(stats.client).stats()).single.warning,
      isTrue,
    );
    expect(stats.adapter.requests.single.path, '/me/attendance/stats');

    final history = _setup(
      (_) async => jsonBody([
        {
          'session_id': 's1',
          'starts_at': '2026-10-18T03:00:00Z',
          'ends_at': '2026-10-18T04:00:00Z',
          'status': 'present',
          'presence_ratio': 0.9,
          'first_seen_at': '2026-10-18T03:03:00Z',
          'late_minutes': 3,
        },
      ]),
    );
    expect(
      (await ApiStatsRepository(
        history.client,
      ).history('c1')).single.lateMinutes,
      3,
    );
    expect(history.adapter.requests.single.path, '/me/attendance');
    expect(history.adapter.requests.single.queryParameters, {'class_id': 'c1'});
  });

  test('LeaveRepository.mine and create', () async {
    final mine = _setup((_) async => jsonBody([_leaveJson]));
    expect(
      (await ApiLeaveRepository(mine.client).mine()).single.reason,
      'Bị ốm',
    );
    expect(mine.adapter.requests.single.path, '/leave-requests/mine');

    final created = _setup((_) async => jsonBody(_leaveJson, status: 201));
    await ApiLeaveRepository(created.client).create(
      classId: 'c1',
      date: DateTime(2026, 10, 18, 23, 59),
      reason: 'Bị ốm',
    );
    expect(created.adapter.requests.single.path, '/leave-requests');
    expect(_body(created.adapter.requests.single), {
      'class_id': 'c1',
      'date': '2026-10-18',
      'reason': 'Bị ốm',
    });
  });

  test('NotificationRepository endpoints', () async {
    final list = _setup((_) async => jsonBody([_notificationJson]));
    final repo = ApiNotificationRepository(list.client);
    expect((await repo.list(unreadOnly: true)).single.title, 'Tiêu đề');
    expect(list.adapter.requests.single.path, '/notifications');
    expect(list.adapter.requests.single.queryParameters, {'unread_only': true});

    final count = _setup((_) async => jsonBody({'count': 4}));
    expect(await ApiNotificationRepository(count.client).unreadCount(), 4);
    expect(count.adapter.requests.single.path, '/notifications/unread-count');

    final read = _setup((_) async => jsonBody(_notificationJson));
    await ApiNotificationRepository(read.client).markRead(7);
    expect(read.adapter.requests.single.path, '/notifications/7/read');
    expect(read.adapter.requests.single.method, 'POST');

    final all = _setup((_) async => jsonBody({'updated': 2}));
    await ApiNotificationRepository(all.client).markAllRead();
    expect(all.adapter.requests.single.path, '/notifications/read-all');
  });
}
