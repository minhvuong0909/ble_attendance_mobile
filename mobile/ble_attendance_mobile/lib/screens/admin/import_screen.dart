import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../data/file_chooser.dart';
import '../../models/import_report.dart';
import '../../providers/admin_providers.dart';
import '../../providers/repositories.dart';
import '../../providers/teacher_providers.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/status_chip.dart';

const maxImportBytes = 2000000;

/// Nhập danh sách từ file CSV/Excel: chọn file, xem trước (không ghi), rồi xác nhận.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, required this.kind, this.classId});

  /// `students`, `teachers` hoặc `classes`.
  final String kind;
  final String? classId;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  PickedFile? _file;
  ImportReport? _preview;
  int? _importedRows;
  String? _error;
  bool _busy = false;

  static const _titles = {
    'students': 'Nhập danh sách sinh viên',
    'teachers': 'Nhập danh sách giảng viên',
    'classes': 'Nhập danh sách môn và lớp',
  };
  static const _columns = {
    'students': 'student_id, full_name',
    'teachers': 'teacher_id, full_name',
    'classes':
        'course_code, course_name, class_code, semester, teacher_id (không bắt buộc)',
  };

  bool get _supported => _titles.containsKey(widget.kind);

  Future<ImportReport> _call(PickedFile file, {required bool dryRun}) {
    final repo = ref.read(adminRepositoryProvider);
    return switch (widget.kind) {
      'students' => repo.importStudents(widget.classId!, file, dryRun: dryRun),
      'teachers' => repo.importTeachers(file, dryRun: dryRun),
      _ => repo.importClasses(file, dryRun: dryRun),
    };
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndPreview() => _guard(() async {
    final file = await ref.read(fileChooserProvider).pick();
    if (file == null) return;
    final name = file.name.toLowerCase();
    if (!name.endsWith('.csv') && !name.endsWith('.xlsx')) {
      throw ApiException('unsupported_file', 'Chỉ hỗ trợ file .csv hoặc .xlsx');
    }
    if (file.bytes.length > maxImportBytes) {
      throw ApiException('file_too_large', 'File quá lớn (tối đa 2 MB)');
    }
    final report = await _call(file, dryRun: true);
    if (mounted) {
      setState(() {
        _file = file;
        _preview = report;
        _importedRows = null;
      });
    }
  });

  Future<void> _commit() => _guard(() async {
    final file = _file;
    if (file == null) return;
    final report = await _call(file, dryRun: false);
    if (!report.committed) {
      throw ApiException(
        'not_committed',
        'Dữ liệu chưa được ghi, hãy kiểm tra lại file rồi thử lại.',
      );
    }
    ref.invalidate(adminClassesProvider);
    ref.invalidate(adminTeachersProvider);
    ref.invalidate(adminCoursesProvider);
    ref.invalidate(classStudentsProvider);
    if (mounted) {
      setState(() {
        _importedRows = report.created;
        _preview = null;
        _file = null;
      });
    }
  });

  Future<void> _template() => _guard(() async {
    final template = await ref
        .read(adminRepositoryProvider)
        .downloadTemplate(widget.kind);
    await ref.read(fileSharerProvider).share(template.filename, template.bytes);
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_supported) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nhập danh sách')),
        body: const Center(child: Text('Loại danh sách không được hỗ trợ')),
      );
    }
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: Text(_titles[widget.kind]!)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'File CSV (UTF-8) hoặc Excel (.xlsx), tối đa 2 MB, dòng đầu là tiêu đề với các cột:',
          ),
          const SizedBox(height: 4),
          Text(_columns[widget.kind]!, style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _template,
                icon: const Icon(Icons.download),
                label: const Text('Tải file mẫu'),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : _pickAndPreview,
                icon: const Icon(Icons.upload_file),
                label: const Text('Chọn file'),
              ),
            ],
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            ErrorBanner(_error!),
          ],
          if (_importedRows != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.green.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đã nhập $_importedRows dòng',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (preview != null) ..._previewSection(context, preview),
        ],
      ),
    );
  }

  List<Widget> _previewSection(BuildContext context, ImportReport report) {
    final theme = Theme.of(context);
    return [
      const SizedBox(height: 16),
      Text(_file?.name ?? '', style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          Text('Tổng: ${report.total} dòng'),
          Text('Sẽ tạo: ${report.created}'),
          Text('Bỏ qua: ${report.skipped}'),
          Text('Lỗi: ${report.errors}'),
        ],
      ),
      const SizedBox(height: 8),
      for (final row in report.rows)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('Dòng ${row.row}'),
          subtitle: Text(row.message),
          trailing: switch (row.status) {
            ImportRowStatus.created => const StatusChip(
              label: 'Sẽ tạo',
              color: Color(0xFF2E7D32),
            ),
            ImportRowStatus.skipped => const StatusChip(
              label: 'Bỏ qua',
              color: Color(0xFFEF6C00),
            ),
            ImportRowStatus.error => const StatusChip(
              label: 'Lỗi',
              color: Color(0xFFC62828),
            ),
          },
        ),
      const SizedBox(height: 16),
      if (report.errors > 0)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Sửa các dòng lỗi trong file rồi chọn lại file để tiếp tục.',
          ),
        ),
      FilledButton(
        onPressed: _busy || !report.canCommit ? null : _commit,
        child: const Text('Xác nhận nhập'),
      ),
    ];
  }
}
