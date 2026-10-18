enum AppRole {
  admin,
  teacher,
  student;

  static AppRole parse(String value) {
    for (final role in AppRole.values) {
      if (role.name == value) return role;
    }
    throw FormatException('Vai trò không hợp lệ: $value');
  }

  String get homePath => '/$name';

  String get label => switch (this) {
    AppRole.admin => 'Quản trị viên',
    AppRole.teacher => 'Giảng viên',
    AppRole.student => 'Sinh viên',
  };
}
