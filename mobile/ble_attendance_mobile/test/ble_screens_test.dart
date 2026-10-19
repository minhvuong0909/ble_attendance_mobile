import 'package:ble_attendance_mobile/ble/beacon_codec.dart';
import 'package:ble_attendance_mobile/ble/ble_gateway.dart';
import 'package:ble_attendance_mobile/models/app_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';
import 'helpers/harness.dart';

Fakes _withSession() {
  final fakes = Fakes();
  fakes.sessions.onActive = () async => sampleSession();
  return fakes;
}

void main() {
  testWidgets('student starts advertising and shows near/far', (tester) async {
    final fakes = _withSession();
    await openApp(tester, fakes: fakes);
    await tester.pump();
    expect(fakes.ble.advertised, hasLength(1));
    expect(decodeStudent(fakes.ble.advertised.single)!.studentId, '25CE099');
    expect(find.textContaining('Đang tìm tín hiệu'), findsOneWidget);

    fakes.ble.emit(encodeTeacher('abcd1234'), -60);
    await tester.pump();
    await tester.pump();
    expect(find.text('Bạn đang ở trong phạm vi lớp học'), findsOneWidget);
  });

  testWidgets('student without Bluetooth sees the problem and can retry', (
    tester,
  ) async {
    final fakes = _withSession();
    fakes.ble.readiness = BleReadiness.bluetoothOff;
    await openApp(tester, fakes: fakes);
    await tester.pump();
    expect(find.textContaining('Bluetooth đang tắt'), findsOneWidget);
    expect(fakes.ble.advertised, isEmpty);

    fakes.ble.readiness = BleReadiness.ready;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Thử lại'));
    await tester.pump();
    await tester.pump();
    expect(fakes.ble.advertised, hasLength(1));
    expect(find.textContaining('Bluetooth đang tắt'), findsNothing);
  });

  testWidgets('no session means no BLE activity', (tester) async {
    final fakes = Fakes();
    await openApp(tester, fakes: fakes);
    await tester.pump();
    expect(fakes.ble.advertised, isEmpty);
    expect(fakes.ble.scanStarts, 0);
  });

  testWidgets('teacher advertises the session code and counts students', (
    tester,
  ) async {
    final fakes = _withSession();
    await openApp(
      tester,
      fakes: fakes,
      role: AppRole.teacher,
      tab: 'Buổi trực tiếp',
    );
    await tester.pump();
    expect(decodeTeacher(fakes.ble.advertised.single), 'abcd1234');
    fakes.ble.emit(encodeStudent('25CE099', 'deadbeef'), -60);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Đã thấy 1 sinh viên'), findsOneWidget);
  });
}
