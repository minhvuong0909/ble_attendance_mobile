import 'dart:async';

import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/widgets/error_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';
import 'helpers/harness.dart';

Finder get _button => find.widgetWithText(FilledButton, 'Xác nhận điểm danh');

Future<Fakes> _open(WidgetTester tester, {bool finalizationOpen = true}) async {
  final fakes = Fakes();
  fakes.sessions.onActive = () async =>
      sampleSession(finalizationOpen: finalizationOpen);
  return openApp(tester, fakes: fakes);
}

void main() {
  testWidgets('shows a message when there is no active session', (
    tester,
  ) async {
    await openApp(tester);
    expect(find.text('Chưa có buổi học nào đang diễn ra'), findsOneWidget);
    expect(_button, findsNothing);
  });

  testWidgets('shows the session card with the course and class', (
    tester,
  ) async {
    await _open(tester, finalizationOpen: false);
    expect(find.text('Lập trình di động'), findsOneWidget);
    expect(find.textContaining('SE1901'), findsWidgets);
    expect(find.text('Buổi học đang diễn ra'), findsOneWidget);
  });

  testWidgets('the button is disabled until the teacher opens finalization', (
    tester,
  ) async {
    await _open(tester, finalizationOpen: false);
    expect(find.text('Chờ giảng viên mở chốt điểm danh'), findsOneWidget);
    expect(tester.widget<FilledButton>(_button).onPressed, isNull);
  });

  testWidgets(
    'a confirmed finalization authenticates, calls the API once and shows success',
    (tester) async {
      final fakes = await _open(tester);
      expect(tester.widget<FilledButton>(_button).onPressed, isNotNull);
      await tester.tap(_button);
      await tester.pumpAndSettle();
      expect(fakes.authenticator.calls, 1);
      expect(fakes.sessions.finalized, ['s1']);
      expect(find.text('Đã xác nhận điểm danh'), findsOneWidget);
      expect(_button, findsNothing);
    },
  );

  testWidgets('tapping twice quickly calls the API only once', (tester) async {
    final gate = Completer<bool>();
    final fakes = await _open(tester);
    fakes.authenticator.onAuthenticate = (_) => gate.future;
    await tester.tap(_button);
    await tester.pump();
    await tester.tap(_button, warnIfMissed: false);
    await tester.pump();
    gate.complete(true);
    await tester.pumpAndSettle();
    expect(fakes.authenticator.calls, 1);
    expect(fakes.sessions.finalized, ['s1']);
  });

  testWidgets(
    'cancelling the device authentication calls nothing and shows no error',
    (tester) async {
      final fakes = await _open(tester);
      fakes.authenticator.onAuthenticate = (_) async => false;
      await tester.tap(_button);
      await tester.pumpAndSettle();
      expect(fakes.sessions.finalized, isEmpty);
      expect(find.byType(ErrorBanner), findsNothing);
      expect(_button, findsOneWidget);
    },
  );

  testWidgets('an authenticator failure is reported', (tester) async {
    final fakes = await _open(tester);
    fakes.authenticator.onAuthenticate = (_) async => throw ApiException(
      'device_auth_unavailable',
      'Thiết bị chưa cài khóa màn hình',
    );
    await tester.tap(_button);
    await tester.pumpAndSettle();
    expect(find.text('Thiết bị chưa cài khóa màn hình'), findsOneWidget);
    expect(fakes.sessions.finalized, isEmpty);
  });

  testWidgets('a server rejection shows its message and allows trying again', (
    tester,
  ) async {
    final fakes = await _open(tester);
    var attempts = 0;
    fakes.sessions.onFinalize = (_) async {
      attempts++;
      if (attempts == 1) {
        throw ApiException(
          'not_in_range',
          'Chưa phát hiện bạn trong lớp, hãy lại gần giảng viên',
        );
      }
    };
    await tester.tap(_button);
    await tester.pumpAndSettle();
    expect(
      find.text('Chưa phát hiện bạn trong lớp, hãy lại gần giảng viên'),
      findsOneWidget,
    );

    await tester.tap(_button);
    await tester.pumpAndSettle();
    expect(find.text('Đã xác nhận điểm danh'), findsOneWidget);
    expect(find.byType(ErrorBanner), findsNothing);
  });

  testWidgets('refreshes every 15 seconds and picks up a new session', (
    tester,
  ) async {
    final fakes = Fakes();
    SessionHolder.session = null;
    fakes.sessions.onActive = () async => SessionHolder.session;
    await openApp(tester, fakes: fakes);
    expect(find.text('Chưa có buổi học nào đang diễn ra'), findsOneWidget);

    SessionHolder.session = sampleSession(finalizationOpen: true);
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.text('Lập trình di động'), findsOneWidget);
    expect(fakes.sessions.activeCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('a loading error offers a retry', (tester) async {
    final fakes = Fakes();
    var calls = 0;
    fakes.sessions.onActive = () async {
      calls++;
      if (calls == 1) throw ApiException('network', 'Mất kết nối');
      return sampleSession();
    };
    await openApp(tester, fakes: fakes);
    expect(find.text('Mất kết nối'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Lập trình di động'), findsOneWidget);
  });
}

class SessionHolder {
  static dynamic session;
}
