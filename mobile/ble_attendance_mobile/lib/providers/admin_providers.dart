import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_user.dart';
import '../models/class_info.dart';
import '../models/course.dart';
import 'repositories.dart';

final adminCoursesProvider = FutureProvider.autoDispose<List<Course>>(
  (ref) => ref.watch(adminRepositoryProvider).courses(),
);

final adminClassesProvider = FutureProvider.autoDispose<List<ClassInfo>>(
  (ref) => ref.watch(adminRepositoryProvider).allClasses(),
);

final adminTeachersProvider = FutureProvider.autoDispose<List<AuthUser>>(
  (ref) => ref.watch(adminRepositoryProvider).teachers(),
);
