import 'Shuttle_status.dart';
import 'Shuttle_type.dart';

class Shuttle {
  final String shuttleId;
  String licensePlate;
  String model;
  int capacity;
  ShuttleStatus shuttleStatus;
  ShuttleType shuttleType;

  Shuttle({
    required this.shuttleId,
    required this.licensePlate,
    required this.model,
    required this.capacity,
    required this.shuttleStatus,
    required this.shuttleType,
  });

  Shuttle copyWith({
    String? shuttleId,
    String? licensePlate,
    String? model,
    int? capacity,
    ShuttleStatus? shuttleStatus,
    ShuttleType? shuttleType,
  }) {
    return Shuttle(
      shuttleId: shuttleId ?? this.shuttleId,
      licensePlate: licensePlate ?? this.licensePlate,
      model: model ?? this.model,
      capacity: capacity ?? this.capacity,
      shuttleStatus: shuttleStatus ?? this.shuttleStatus,
      shuttleType: shuttleType ?? this.shuttleType,
    );
  }

  // JSON serialization/deserialization
  factory Shuttle.fromJson(Map<String, dynamic> json) {
    return Shuttle(
      shuttleId: json['shuttleId'],
      licensePlate: json['licensePlate'],
      model: json['model'],
      capacity: json['capacity'],
      shuttleStatus: ShuttleStatus.values.firstWhere(
        (e) => e.toString() == 'ShuttleStatus.${json['shuttleStatus']}',
      ),
      shuttleType: ShuttleType.values.firstWhere(
        (e) => e.toString() == 'ShuttleType.${json['shuttleType']}',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'shuttleId': shuttleId,
    'licensePlate': licensePlate,
    'model': model,
    'capacity': capacity,
    'shuttleStatus': shuttleStatus.toString().split('.').last,
    'shuttleType': shuttleType.toString().split('.').last,
  };
}
