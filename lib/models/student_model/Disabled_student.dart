import 'Student.dart';

enum DisabilityType {
  visual,
  hearing,
  mobility,
  cognitive,
  other,
  // Add more types as needed
}

class DisabledStudent {
  final int disabledId; // Java Long -> Dart int
  Student student;
  DisabilityType disabilityType;
  bool requiresMinibus;

  DisabledStudent({
    required this.disabledId,
    required this.student,
    required this.disabilityType,
    required this.requiresMinibus,
  });

  // JSON serialization/deserialization
  factory DisabledStudent.fromJson(Map<String, dynamic> json) {
    return DisabledStudent(
      disabledId: json['disabledId'],
      student: Student.fromJson(json['student']),
      disabilityType: DisabilityType.values.firstWhere(
              (e) => e.toString() == 'DisabilityType.${json['disabilityType']}'),
      requiresMinibus: json['requiresMinibus'],
    );
  }

  Map<String, dynamic> toJson() => {
    'disabledId': disabledId,
    'student': student.toJson(),
    'disabilityType': disabilityType.toString().split('.').last,
    'requiresMinibus': requiresMinibus,
  };
}