import 'Route.dart' as DriverRoute;

class Stop {
  final String stopId;
  DriverRoute.Route route;
  String stopName;
  int sequence;

  Stop({
    required this.stopId,
    required this.route,
    required this.stopName,
    required this.sequence,
  });

  Stop copyWith({
    String? stopId,
    DriverRoute.Route? route,
    String? stopName,
    int? sequence,
  }) {
    return Stop(
      stopId: stopId ?? this.stopId,
      route: route ?? this.route,
      stopName: stopName ?? this.stopName,
      sequence: sequence ?? this.sequence,
    );
  }

  // JSON serialization/deserialization
  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      stopId: json['stopId'],
      route: DriverRoute.Route.fromJson(json['route']),
      stopName: json['stopName'],
      sequence: json['sequence'],
    );
  }

  Map<String, dynamic> toJson() => {
    'stopId': stopId,
    'route': route.toJson(),
    'stopName': stopName,
    'sequence': sequence,
  };
}
