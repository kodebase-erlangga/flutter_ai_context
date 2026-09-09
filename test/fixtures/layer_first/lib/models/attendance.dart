class Attendance {
  Attendance({required this.id});

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(id: json['id'] as String);
  }

  final String id;
}
