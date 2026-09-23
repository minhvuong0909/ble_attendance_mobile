// Kiểm tra cơ bản rằng ứng dụng khởi chạy đúng màn hình đăng nhập.

import 'package:flutter_test/flutter_test.dart';

import 'package:ble_attendance_mobile/main.dart';

void main() {
  testWidgets('App loads login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BleAttendanceApp());
    expect(find.text('BLE Attendance Login'), findsOneWidget);
  });
}
