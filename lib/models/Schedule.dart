import 'driver_model/Route.dart';
import 'driver_model/Shuttle.dart';

class Schedule {
  final int scheduleId; // Java Long -> Dart int
  Route route;
  Shuttle shuttle;
  DateTime departureTime; // LocalTime -> DateTime
  DateTime arrivalTime;

  Schedule({
    required this.scheduleId,
    required this.route,
    required this.shuttle,
    required this.departureTime,
    required this.arrivalTime,
  });

  // JSON serialization/deserialization (for API or local storage)
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
