import 'dart:async';

import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:ble_attendance_mobile/models/session_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';
import 'helpers/harness.dart';

SessionInfo _session({String id = 's1', bool active = true, DateTime? ends}) =>
    SessionInfo(
      id: id,
      classId: 'c1',
      classCode: 'SE1901',
      courseCode: 'PRM393',
      courseName: 'Lập trình di động',
      teacherUserId: 't1',
      beaconCode: 'abcd1234',
      startsAt: DateTime(2026, 10, 18, 10, 0),
      endsAt: ends,
      isActive: active,
      finalizationOpen: false,
      beaconSecret: null,
    );

Fakes _fakesWithClass() {
  final fakes = Fakes();
  fakes.classes.onMyClasses = () async => [
    sampleClass(joinCode: 'ABC123', studentCount: 2),
  ];
  fakes.classes.onStudents = (_) async => [
    sampleStudent(id: 'u1', studentId: '25CE099', name: 'Nguyen Van A'),
    sampleStudent(id: 'u2', studentId: '25CE100', name: 'Tran Thi B'),
  ];
  return fakes;
}

Future<Fakes> _openDetail(WidgetTester tester, Fakes fakes) async {
  await openApp(tester, fakes: fakes, role: AppRole.teacher);
  await tester.tap(find.text('Lập trình di động'));
  await tester.pumpAndSettle();
  return fakes;
}

void main() {
  testWidgets('lists assigned classes with student count and join code', (
    tester,
  ) async {
    await openApp(tester, fakes: _fakesWithClass(), role: AppRole.teacher);
    expect(find.text('Lập trình di động'), findsOneWidget);
    expect(find.text('PRM393 · SE1901 · FA26'), findsOneWidget);
    expect(find.text('2 sinh viên'), findsOneWidget);
    expect(find.text('Mã lớp: ABC123'), findsOneWidget);
  });

  testWidgets('copies the join code to the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await openApp(tester, fakes: _fakesWithClass(), role: AppRole.teacher);
    await tester.tap(find.byTooltip('Sao chép mã lớp'));
    await tester.pumpAndSettle();
    expect(copied, 'ABC123');
    expect(find.text('Đã sao chép mã lớp'), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await openApp(tester, role: AppRole.teacher);
    expect(find.text('Bạn chưa được phân công lớp nào'), findsOneWidget);
  });

  testWidgets('a loading error offers a retry', (tester) async {
    final fakes = Fakes();
    var calls = 0;
    fakes.classes.onMyClasses = () async {
      calls++;
      if (calls == 1) throw ApiException('network', 'Mất kết nối');
      return [sampleClass(joinCode: 'ABC123')];
    };
    await openApp(tester, fakes: fakes, role: AppRole.teacher);
    expect(find.text('Mất kết nối'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Lập trình di động'), findsOneWidget);
  });

  testWidgets('the detail page lists students sorted as returned', (
    tester,
  ) async {
    await _openDetail(tester, _fakesWithClass());
    expect(find.text('Sinh viên'), findsWidgets);
    expect(find.text('25CE099 · Nguyen Van A'), findsOneWidget);
    expect(find.text('25CE100 · Tran Thi B'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('25CE099 · Nguyen Van A')).dy,
      lessThan(tester.getTopLeft(find.text('25CE100 · Tran Thi B')).dy),
    );
  });

  testWidgets('empty students tab', (tester) async {
    final fakes = _fakesWithClass();
    fakes.classes.onStudents = (_) async => [];
    await _openDetail(tester, fakes);
    expect(find.text('Chưa có sinh viên nào trong lớp'), findsOneWidget);
  });

  testWidgets('the sessions tab shows history with status', (tester) async {
    final fakes = _fakesWithClass();
    fakes.sessions.onClassSessions = (_) async => [
      _session(id: 's2'),
      _session(id: 's1', active: false, ends: DateTime(2026, 10, 18, 11, 30)),
    ];
    await _openDetail(tester, fakes);
    await tester.tap(find.text('Buổi học'));
    await tester.pumpAndSettle();
    expect(find.text('Đang diễn ra'), findsOneWidget);
    expect(find.textContaining('Đã kết thúc · 90 phút'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Bắt đầu buổi học'),
          )
          .onPressed,
      isNull,
      reason: 'a session is already running',
    );
  });

  testWidgets('starting a session calls the API once and opens the live tab', (
    tester,
  ) async {
    final fakes = _fakesWithClass();
    final gate = Completer<SessionInfo>();
    fakes.sessions.onStart = (_) => gate.future;
    await _openDetail(tester, fakes);
    await tester.tap(find.text('Buổi học'));
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, 'Bắt đầu buổi học');
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();
    gate.complete(_session());
    await tester.pumpAndSettle();

    expect(fakes.sessions.started, ['c1']);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Buổi trực tiếp'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a rejected start shows the server message and stays', (
    tester,
  ) async {
    final fakes = _fakesWithClass();
    fakes.sessions.onStart = (_) async => throw ApiException(
      'session_already_active',
      'Bạn đang có một buổi học chưa kết thúc',
    );
    await _openDetail(tester, fakes);
    await tester.tap(find.text('Buổi học'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Bắt đầu buổi học'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn đang có một buổi học chưa kết thúc'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Bắt đầu buổi học'),
      findsOneWidget,
    );
  });
}
