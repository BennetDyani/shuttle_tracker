import 'Stop.dart';
import '../Schedule.dart';

class Route {
  final String routeId;
  String origin;
  String destination;
  List<Stop> stops;
  List<Schedule> schedules;

  Route({
    required this.routeId,
    required this.origin,
    required this.destination,
    List<Stop>? stops,
    List<Schedule>? schedules,
  })  : stops = stops ?? [],
        schedules = schedules ?? [];

  Route copyWith({
    String? routeId,
    String? origin,
    String? destination,
    List<Stop>? stops,
    List<Schedule>? schedules,
  }) {
    return Route(
      routeId: routeId ?? this.routeId,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      stops: stops ?? this.stops,
      schedules: schedules ?? this.schedules,
    );
  }

  // JSON serialization/deserialization
  factory Route.fromJson(Map<String, dynamic> json) {
    return Route(
      routeId: json['routeId'],
      origin: json['origin'],
      destination: json['destination'],
      stops: (json['stops'] as List<dynamic>?)
          ?.map((s) => Stop.fromJson(s))
          .toList() ??
          [],
      schedules: (json['schedules'] as List<dynamic>?)
          ?.map((s) => Schedule.fromJson(s))
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'routeId': routeId,
    'origin': origin,
    'destination': destination,
    'stops': stops.map((s) => s.toJson()).toList(),
    'schedules': schedules.map((s) => s.toJson()).toList(),
  };
}
