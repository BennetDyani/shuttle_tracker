import '../User.dart';
import 'Disabled_student.dart';

class Student {
  final int studentId; // Java Long -> Dart int
  User user;
  DisabledStudent? disabledStudent; // optional

  Student({
    required this.studentId,
    required this.user,
    this.disabledStudent,
  });

  // JSON serialization/deserialization
  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      studentId: json['studentId'],
      user: User.fromJson(json['user']),
      disabledStudent: json['disabledStudent'] != null
          ? DisabledStudent.fromJson(json['disabledStudent'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'user': user.toJson(),
    'disabledStudent': disabledStudent?.toJson(),
  };
}
