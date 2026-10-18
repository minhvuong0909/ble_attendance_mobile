import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/class_repository.dart';
import '../data/device_authenticator.dart';
import '../data/leave_repository.dart';
import '../data/notification_repository.dart';
import '../data/session_repository.dart';
import '../data/stats_repository.dart';
import 'core_providers.dart';

final classRepositoryProvider = Provider<ClassRepository>(
  (ref) => ApiClassRepository(ref.watch(apiClientProvider)),
);
final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => ApiSessionRepository(ref.watch(apiClientProvider)),
);
final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => ApiStatsRepository(ref.watch(apiClientProvider)),
);
final leaveRepositoryProvider = Provider<LeaveRepository>(
  (ref) => ApiLeaveRepository(ref.watch(apiClientProvider)),
);
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => ApiNotificationRepository(ref.watch(apiClientProvider)),
);
final deviceAuthenticatorProvider = Provider<DeviceAuthenticator>(
  (ref) => LocalAuthAuthenticator(),
);
