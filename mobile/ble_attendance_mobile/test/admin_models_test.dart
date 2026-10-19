import 'package:ble_attendance_mobile/models/course.dart';
import 'package:ble_attendance_mobile/models/import_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Course.fromJson with and without credits', () {
    final a = Course.fromJson({
      'id': 'k1',
      'code': 'PRM393',
      'name': 'Lập trình di động',
      'credits': 3,
    });
    expect(a.code, 'PRM393');
    expect(a.credits, 3);
    expect(
      Course.fromJson({
        'id': 'k2',
        'code': 'X',
        'name': 'Y',
        'credits': null,
      }).credits,
      isNull,
    );
  });

  Map<String, dynamic> report({
    int created = 2,
    int skipped = 1,
    int errors = 0,
    bool committed = false,
  }) => {
    'kind': 'students',
    'dry_run': true,
    'committed': committed,
    'total': created + skipped + errors,
    'created': created,
    'skipped': skipped,
    'errors': errors,
    'rows': [
      {
        'row': 2,
        'status': 'created',
        'message': 'Tạo tài khoản và thêm vào lớp',
      },
      {'row': 3, 'status': 'skipped', 'message': 'Đã ở trong lớp'},
      {'row': 4, 'status': 'error', 'message': 'Mã sinh viên không hợp lệ'},
    ],
  };

  test('ImportReport.fromJson parses every row status', () {
    final r = ImportReport.fromJson(report(errors: 1));
    expect(r.rows.map((x) => x.status), [
      ImportRowStatus.created,
      ImportRowStatus.skipped,
      ImportRowStatus.error,
    ]);
    expect(r.rows.first.row, 2);
    expect(r.dryRun, isTrue);
    expect(r.errors, 1);
  });

  test('canCommit needs no errors and at least one created row', () {
    expect(ImportReport.fromJson(report()).canCommit, isTrue);
    expect(ImportReport.fromJson(report(errors: 1)).canCommit, isFalse);
    expect(ImportReport.fromJson(report(created: 0)).canCommit, isFalse);
  });

  test('an unknown row status is rejected', () {
    expect(() => ImportRowStatus.parse('weird'), throwsFormatException);
  });
}
