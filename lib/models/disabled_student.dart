class DisabledStudent {
  final int disabledId;
  final int studentId;
  final String disabilityType;
  final bool exposureMinibus;
  final String accessNeeds;

  DisabledStudent({
    required this.disabledId,
    required this.studentId,
    required this.disabilityType,
    required this.exposureMinibus,
    required this.accessNeeds,
  });

  factory DisabledStudent.fromMap(Map<String, dynamic> map) {
    return DisabledStudent(
      disabledId: map['disabled_id'],
      studentId: map['student_id'],
      disabilityType: map['disability_type'],
      exposureMinibus: map['exposure_minibus'] == 1,
      accessNeeds: map['access_needs'] ?? '',
    );
  }

  @override
  String toString() {
    return 'DisabledStudent{disabledId: $disabledId, studentId: $studentId, disabilityType: $disabilityType, exposureMinibus: $exposureMinibus, accessNeeds: $accessNeeds}';
  }

  Map<String, dynamic> toMap() {
    return {
      'disabled_id': disabledId,
      'student_id': studentId,
      'disability_type': disabilityType,
      'exposure_minibus': exposureMinibus ? 1 : 0,
      'access_needs': accessNeeds,
    };
  }
}