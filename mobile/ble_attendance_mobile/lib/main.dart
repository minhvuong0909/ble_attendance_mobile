import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'providers/retry.dart';

void main() {
  runApp(const ProviderScope(retry: noAutoRetry, child: App()));
}
