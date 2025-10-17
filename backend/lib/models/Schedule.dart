import 'driver_model/Route.dart';
import 'driver_model/Shuttle.dart';

class Schedule {
  final String scheduleId;
  Route route;
  Shuttle shuttle;
  DateTime departureTime;
  DateTime arrivalTime;

  Schedule({
    required this.scheduleId,
    required this.route,
    required this.shuttle,
    required this.departureTime,
    required this.arrivalTime,
  });

  Schedule copyWith({
    String? scheduleId,
    Route? route,
    Shuttle? shuttle,
    DateTime? departureTime,
    DateTime? arrivalTime,
  }) {
    return Schedule(
      scheduleId: scheduleId ?? this.scheduleId,
      route: route ?? this.route,
      shuttle: shuttle ?? this.shuttle,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
    );
  }

  // JSON serialization/deserialization
  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      scheduleId: json['scheduleId'],
      route: Route.fromJson(json['route']),
      shuttle: Shuttle.fromJson(json['shuttle']),
      departureTime: DateTime.parse(json['departureTime']),
      arrivalTime: DateTime.parse(json['arrivalTime']),
    );
  }

  Map<String, dynamic> toJson() => {
    'scheduleId': scheduleId,
    'route': route.toJson(),
    'shuttle': shuttle.toJson(),
    'departureTime': departureTime.toIso8601String(),
    'arrivalTime': arrivalTime.toIso8601String(),
  };
}
