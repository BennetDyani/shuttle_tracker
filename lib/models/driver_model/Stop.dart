import 'Route.dart' as DriverRoute;

class Stop {
  final int stopId; // Java Long -> Dart int
  DriverRoute.Route route;
  String stopName;
  int sequence;

  Stop({
    required this.stopId,
    required this.route,
    required this.stopName,
    required this.sequence,
  });

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
