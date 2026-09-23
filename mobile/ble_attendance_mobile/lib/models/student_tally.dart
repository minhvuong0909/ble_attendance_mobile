class StudentTally {
  StudentTally({required this.studentId});

  final String studentId;
  int hits = 0;
  int total = 0;
  int? latestRssi;
  DateTime? latestAt;
  bool inRange = false;
}
