import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../core/app_constants.dart';
import 'ble_permissions.dart';
import 'foreground_service.dart';

enum BleReadiness { ready, permissionDenied, bluetoothOff, unsupported }

/// Một gói quảng cáo của app bắt được (đã bỏ 2 byte company id).
class BleSighting {
  const BleSighting(this.payload, this.rssi);
  final Uint8List payload;
  final int rssi;
}

/// Lớp mỏng quanh phần cứng BLE để các bộ điều khiển test được bằng bản giả.
abstract class BleGateway {
  Future<BleReadiness> ensureReady({required bool advertise});
  Future<void> startAdvertising(Uint8List payload);
  Future<void> stopAdvertising();

  /// Giữ app sống ở nền (foreground service) trong lúc phát/quét.
  Future<void> startKeepAlive(String text);
  Future<void> stopKeepAlive();

  /// Luồng gói của app; kết thúc bằng lỗi nếu quét thất bại.
  Stream<BleSighting> scan();
}

class RealBleGateway implements BleGateway {
  RealBleGateway({FlutterReactiveBle? ble, FlutterBlePeripheral? peripheral})
    : _ble = ble ?? FlutterReactiveBle(),
      _peripheral = peripheral ?? FlutterBlePeripheral();

  final FlutterReactiveBle _ble;
  final FlutterBlePeripheral _peripheral;

  @override
  Future<BleReadiness> ensureReady({required bool advertise}) async {
    final granted = advertise
        ? await ensureBlePermissions()
        : await ensureBleScanPermissions();
    if (!granted) return BleReadiness.permissionDenied;
    if (advertise && !await _peripheral.isSupported) {
      return BleReadiness.unsupported;
    }
    final status = await _ble.statusStream
        .firstWhere((s) => s != BleStatus.unknown)
        .timeout(const Duration(seconds: 3), onTimeout: () => BleStatus.ready);
    if (status == BleStatus.poweredOff) {
      await ensureBluetoothEnabled(); // hộp thoại bật Bluetooth của hệ thống
      return BleReadiness.bluetoothOff;
    }
    if (status == BleStatus.unauthorized) return BleReadiness.permissionDenied;
    if (status == BleStatus.unsupported) return BleReadiness.unsupported;
    return BleReadiness.ready;
  }

  @override
  Future<void> startAdvertising(Uint8List payload) async {
    await _peripheral.stop();
    await _peripheral.start(
      advertiseData: AdvertiseData(
        manufacturerId: manufacturerId,
        manufacturerData: payload,
      ),
      advertiseSettings: AdvertiseSettings(
        advertiseSet: false,
        connectable: false,
        timeout: 0,
        advertiseMode: AdvertiseMode.advertiseModeLowLatency,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
      ),
    );
  }

  @override
  Future<void> stopAdvertising() async {
    await _peripheral.stop();
  }

  @override
  Future<void> startKeepAlive(String text) => startForegroundService(text);

  @override
  Future<void> stopKeepAlive() => stopForegroundService();

  @override
  Stream<BleSighting> scan() {
    return _ble
        .scanForDevices(
          withServices: const [],
          scanMode: ScanMode.lowLatency,
          requireLocationServicesEnabled: false,
        )
        .map((device) {
          final data = device.manufacturerData;
          if (data.length < 3) return null;
          // 2 byte đầu là company id (little endian).
          if (data[0] != (manufacturerId & 0xFF) ||
              data[1] != (manufacturerId >> 8)) {
            return null;
          }
          return BleSighting(Uint8List.fromList(data.sublist(2)), device.rssi);
        })
        .where((s) => s != null)
        .cast<BleSighting>();
  }
}

/// Bản giả dùng trong test.
class FakeBleGateway implements BleGateway {
  BleReadiness readiness = BleReadiness.ready;
  final advertised = <Uint8List>[];
  int stops = 0;
  int scanStarts = 0;
  int keepAliveStarts = 0;
  int keepAliveStops = 0;
  StreamController<BleSighting>? _controller;

  void emit(Uint8List payload, int rssi) =>
      _controller?.add(BleSighting(payload, rssi));
  void failScan() => _controller?.addError(StateError('scan failed'));

  @override
  Future<BleReadiness> ensureReady({required bool advertise}) async =>
      readiness;
  @override
  Future<void> startAdvertising(Uint8List payload) async =>
      advertised.add(payload);
  @override
  Future<void> stopAdvertising() async => stops++;
  @override
  Future<void> startKeepAlive(String text) async => keepAliveStarts++;
  @override
  Future<void> stopKeepAlive() async => keepAliveStops++;
  @override
  Stream<BleSighting> scan() {
    scanStarts++;
    _controller = StreamController<BleSighting>();
    return _controller!.stream;
  }
}
