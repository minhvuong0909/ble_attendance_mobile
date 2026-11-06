import 'dart:async';

import 'package:ble_attendance_mobile/ble/ble_gateway.dart';
import 'package:ble_attendance_mobile/ble/beacon_codec.dart';
import 'package:ble_attendance_mobile/providers/core_providers.dart';
import 'package:ble_attendance_mobile/providers/repositories.dart';
import 'package:ble_attendance_mobile/providers/student_beacon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

class _Setup {
  _Setup() {
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        bleGatewayProvider.overrideWithValue(ble),
        clockProvider.overrideWithValue(() => now),
      ],
    );
  }
  final ble = FakeBleGateway();
  DateTime now = DateTime.utc(2026, 10, 18, 3, 0, 5);
  late final ProviderContainer container;
  StudentBeaconController get controller =>
      container.read(studentBeaconProvider.notifier);
  StudentBeaconState get state => container.read(studentBeaconProvider);
}

final _teacher = encodeTeacher('abcd1234');

void main() {
  testWidgets('syncing again while the permission prompt is open asks only once', (
    tester,
  ) async {
    final s = _Setup();
    addTearDown(s.container.dispose);
    final gate = Completer<void>();
    s.ble.readyGate = gate;
    final first = s.controller.sync(sampleSession(), '25CE099');
    await tester.pump();
    await s.controller.sync(sampleSession(), '25CE099');
    await s.controller.sync(sampleSession(), '25CE099');
    expect(s.ble.ensureReadyCalls, 1);
    expect(s.ble.stops, 0);
    gate.complete();
    await first;
    expect(s.state.active, isTrue);
    await s.controller.stop();
  });

  testWidgets('advertises the HMAC tag of the current bucket', (tester) async {
    final s = _Setup();
    addTearDown(s.container.dispose);
    await s.controller.sync(sampleSession(), '25CE099');
    final decoded = decodeStudent(s.ble.advertised.single)!;
    expect(decoded.studentId, '25CE099');
    expect(decoded.tag, makeTag('secret', bucketOf(s.now)));
    expect(s.ble.keepAliveStarts, 1);
    expect(s.state.active, isTrue);
    await s.controller.stop();
  });

  testWidgets('re-advertises when the bucket changes, not before', (
    tester,
  ) async {
    final s = _Setup();
    addTearDown(s.container.dispose);
    await s.controller.sync(sampleSession(), '25CE099');
    s.now = s.now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 5));
    expect(s.ble.advertised, hasLength(1));
    s.now = s.now.add(const Duration(seconds: 25));
    await tester.pump(const Duration(seconds: 5));
    expect(s.ble.advertised, hasLength(2));
    expect(
      decodeStudent(s.ble.advertised.last)!.tag,
      makeTag('secret', bucketOf(s.now)),
    );
    await s.controller.stop();
  });

  testWidgets('near/far follows the median RSSI against the class threshold', (
    tester,
  ) async {
    final s = _Setup();
    addTearDown(s.container.dispose);
    await s.controller.sync(sampleSession(), '25CE099'); // ngưỡng -75
    s.ble.emit(_teacher, -60);
    await tester.pump();
    expect(s.state.proximity, Proximity.near);
    expect(s.state.rssi, -60);
    await s.controller.stop();
  });

  testWidgets('a change of proximity needs to persist for the debounce', (
    tester,
  ) async {
    final s = _Setup();
    addTearDown(s.container.dispose);
    await s.controller.sync(sampleSession(), '25CE099');
    s.ble.emit(_teacher, -60);
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      s.ble.emit(_teacher, -90);
    }
    await tester.pump();
    expect(s.state.proximity, Proximity.near); // mới đổi, chưa đủ 3 giây
    s.now = s.now.add(const Duration(seconds: 4));
    s.ble.emit(_teacher, -90);
    await tester.pump();
    expect(s.state.proximity, Proximity.far);
    await s.controller.stop();
  });

  testWidgets('ignores other sessions and non-teacher packets', (tester) async {
    final s = _Setup();
    addTearDown(s.container.dispose);
    await s.controller.sync(sampleSession(), '25CE099');
    s.ble.emit(encodeTeacher('zzzz9999'), -50);
    s.ble.emit(encodeStudent('25CE100', 'deadbeef'), -50);
    await tester.pump();
    expect(s.state.proximity, Proximity.unknown);
    await s.controller.stop();
  });

  testWidgets('signal lost after 15 seconds returns to unknown', (
    tester,
  ) async {
    final s = _Setup();
    addTearDown(s.container.dispose);
    await s.controller.sync(sampleSession(), '25CE099');
    s.ble.emit(_teacher, -60);
    await tester.pump();
    s.now = s.now.add(const Duration(seconds: 20));
    await tester.pump(const Duration(seconds: 5));
    expect(s.state.proximity, Proximity.unknown);
    expect(s.state.rssi, isNull);
    await s.controller.stop();
  });

  testWidgets('permission or Bluetooth problems are reported, then retried', (
    tester,
  ) async {
    final s = _Setup();
    addTearDown(s.container.dispose);
    s.ble.readiness = BleReadiness.bluetoothOff;
    await s.controller.sync(sampleSession(), '25CE099');
    expect(s.state.problem, BleReadiness.bluetoothOff);
    expect(s.ble.advertised, isEmpty);
    await s.controller.sync(sampleSession(), '25CE099'); // không hỏi lại
    expect(s.state.problem, BleReadiness.bluetoothOff);
    s.ble.readiness = BleReadiness.ready;
    await s.controller.retry();
    expect(s.state.active, isTrue);
    expect(s.ble.advertised, hasLength(1));
    await s.controller.stop();
  });

  testWidgets('stops when the session ends or has no secret', (tester) async {
    final s = _Setup();
    addTearDown(s.container.dispose);
    await s.controller.sync(sampleSession(), '25CE099');
    await s.controller.sync(null, '25CE099');
    expect(s.state.sessionId, isNull);
    expect(s.ble.stops, 1);
    expect(s.ble.keepAliveStops, 1);
    await s.controller.stop();
  });

  testWidgets('a failed scan is flagged and restarted on the next tick', (
    tester,
  ) async {
    final s = _Setup();
    addTearDown(s.container.dispose);
    await s.controller.sync(sampleSession(), '25CE099');
    s.ble.failScan();
    await tester.pump();
    expect(s.state.scanError, isTrue);
    await tester.pump(const Duration(seconds: 5));
    expect(s.ble.scanStarts, 2);
    await s.controller.stop();
  });
}
