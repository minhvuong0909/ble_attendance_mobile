import 'package:ble_attendance_mobile/models/attendance_status.dart';
import 'package:ble_attendance_mobile/models/leave_request.dart';
import 'package:ble_attendance_mobile/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('attendance chips use Vietnamese labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              for (final s in AttendanceStatus.values) attendanceChip(s),
              for (final s in LeaveStatus.values) leaveChip(s),
            ],
          ),
        ),
      ),
    );
    for (final label in [
      'Có mặt',
      'Vắng',
      'Có phép',
      'Chờ duyệt',
      'Đã duyệt',
      'Bị từ chối',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}
