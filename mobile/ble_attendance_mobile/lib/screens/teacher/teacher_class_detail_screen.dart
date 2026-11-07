import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/leave_provider.dart';
import 'class_report_tab.dart';
import 'class_sessions_tab.dart';
import 'class_students_tab.dart';
import 'rssi_dialog.dart';

class TeacherClassDetailScreen extends ConsumerWidget {
  const TeacherClassDetailScreen({super.key, required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref
        .watch(myClassListProvider)
        .value
        ?.where((c) => c.id == classId)
        .firstOrNull;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(info?.title ?? 'Chi tiết lớp'),
          actions: [
            if (info != null)
              IconButton(
                tooltip: 'Ngưỡng RSSI',
                icon: const Icon(Icons.tune),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final saved = await showRssiDialog(
                    context,
                    classId: classId,
                    current: info.rssiThreshold,
                  );
                  if (saved == true) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Đã lưu ngưỡng RSSI')),
                    );
                  }
                },
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sinh viên'),
              Tab(text: 'Buổi học'),
              Tab(text: 'Báo cáo'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ClassStudentsTab(classId: classId),
            ClassSessionsTab(classId: classId),
            ClassReportTab(classId: classId),
          ],
        ),
      ),
    );
  }
}
