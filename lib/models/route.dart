// lib/models/route.dart
class RouteModel {
  final int routeId;
  final String origin;
  final String destination;

  RouteModel({
    required this.routeId,
    required this.origin,
    required this.destination,
  });

  factory RouteModel.fromMap(Map<String, dynamic> map) {
    return RouteModel(
      routeId: map['route_id'],
      origin: map['origin'],
      destination: map['destination'],
    );
  }
}

// lib/models/schedule.dart
class Schedule {
  final int scheduleId;
  final int shuttleId;
  final int routeId;
  final DateTime departureTime;
  final DateTime arrivalTime;

  Schedule({
    required this.scheduleId,
    required this.shuttleId,
    required this.routeId,
    required this.departureTime,
    required this.arrivalTime,
  });

  factory Schedule.fromMap(Map<String, dynamic> map) {
    return Schedule(
      scheduleId: map['schedule_id'],
      shuttleId: map['shuttle_id'],
      routeId: map['route_id'],
      departureTime: DateTime.parse(map['departure_time']),
      arrivalTime: DateTime.parse(map['arrival_time']),
    );
  }
}
