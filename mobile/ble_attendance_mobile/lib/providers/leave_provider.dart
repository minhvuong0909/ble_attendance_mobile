import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/class_info.dart';
import '../models/leave_request.dart';
import 'repositories.dart';

final myLeaveProvider = FutureProvider.autoDispose<List<LeaveRequest>>(
  (ref) => ref.watch(leaveRepositoryProvider).mine(),
);

final myClassListProvider = FutureProvider.autoDispose<List<ClassInfo>>(
  (ref) => ref.watch(classRepositoryProvider).myClasses(),
);
