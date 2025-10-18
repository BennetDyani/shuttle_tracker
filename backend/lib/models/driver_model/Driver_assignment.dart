import 'package:uuid/uuid.dart';

import 'Driver.dart';
import 'Shuttle.dart';

class DriverAssignment {
  final String assignmentId; // UUID
  Driver driver;
  Shuttle shuttle;
  DateTime startTime;
  DateTime endTime;

  DriverAssignment({
    String? assignmentId,
    required this.driver,
    required this.shuttle,
    required this.startTime,
    required this.endTime,
  }) : assignmentId = assignmentId ?? const Uuid().v4();

  DriverAssignment copyWith({
    String? assignmentId,
    Driver? driver,
    Shuttle? shuttle,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return DriverAssignment(
      assignmentId: assignmentId ?? this.assignmentId,
      driver: driver ?? this.driver,
      shuttle: shuttle ?? this.shuttle,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  // JSON serialization/deserialization
  factory DriverAssignment.fromJson(Map<String, dynamic> json) {
    return DriverAssignment(
      assignmentId: json['assignmentId'],
      driver: Driver.fromJson(json['driver']),
      shuttle: Shuttle.fromJson(json['shuttle']),
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
    );
  }

  Map<String, dynamic> toJson() => {
    'assignmentId': assignmentId,
    'driver': driver.toJson(),
    'shuttle': shuttle.toJson(),
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
  };
}
