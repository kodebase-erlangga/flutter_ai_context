class AttendanceModel {
  AttendanceModel({required this.id, required this.status});

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] as String,
      status: json['status'] as String,
    );
  }

  final String id;
  final String status;

  Map<String, dynamic> toJson() => {'id': id, 'status': status};
}
