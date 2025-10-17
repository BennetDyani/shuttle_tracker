import 'driver.dart';
import 'shuttle.dart';
import 'location_status.dart';

class Location {
  final int locationId;
  final Driver driver;
  final Shuttle shuttle;
  final LocationStatus locationStatus;
  final DateTime recordedAt;

  Location({
    required this.locationId,
    required this.driver,
    required this.shuttle,
    required this.locationStatus,
    required this.recordedAt,
  });

  // Deserialize from JSON
  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      locationId: json['locationId'],
      driver: Driver.fromJson(json['driver']),
      shuttle: Shuttle.fromJson(json['shuttle']),
      locationStatus: LocationStatusExtension.fromString(json['locationStatus']),
      recordedAt: DateTime.parse(json['recordedAt']),
    );
  }

  // Serialize to JSON
  Map<String, dynamic> toJson() {
    return {
      'locationId': locationId,
      'driver': driver.toJson(),
      'shuttle': shuttle.toJson(),
      'locationStatus': locationStatus.toString().split('.').last,
      'recordedAt': recordedAt.toIso8601String(),
    };
  }
}
