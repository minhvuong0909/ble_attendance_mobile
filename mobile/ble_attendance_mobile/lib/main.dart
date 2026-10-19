import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'ble/foreground_service.dart';
import 'providers/retry.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initForegroundTask();
  runApp(const ProviderScope(retry: noAutoRetry, child: App()));
}
