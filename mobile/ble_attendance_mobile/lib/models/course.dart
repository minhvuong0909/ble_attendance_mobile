class Course {
  const Course({
    required this.id,
    required this.code,
    required this.name,
    required this.credits,
  });

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    credits: json['credits'] as int?,
  );

  final String id;
  final String code;
  final String name;
  final int? credits;
}
