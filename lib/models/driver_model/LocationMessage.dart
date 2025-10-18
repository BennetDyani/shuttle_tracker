import 'location_status.dart';

class LocationMessage {
  final int? driverId;
  final int? shuttleId;
  final LocationStatus locationStatus;
  final DateTime timestamp;

  LocationMessage({
    required this.driverId,
    required this.shuttleId,
    required this.locationStatus,
    required this.timestamp,
  });

  factory LocationMessage.fromJson(Map<String, dynamic> json) {
    return LocationMessage(
      driverId: json['driverId'],
      shuttleId: json['shuttleId'],
      locationStatus: LocationStatusExtension.fromString(json['locationStatus']),
      timestamp: DateTime.parse(json['timestamp'] ?? json['recordedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    // Produce an ISO-like local datetime string without a trailing 'Z' or offset
    var iso = timestamp.toIso8601String();
    // Remove trailing Z (UTC marker) and any timezone offset like +02:00/-05:00
    iso = iso.replaceAll(RegExp(r'Z$'), '').replaceAll(RegExp(r'([+-]\d{2}:\d{2})$'), '');
    return {
      'driverId': driverId,
      'shuttleId': shuttleId,
      'locationStatus': locationStatus.toString().split('.').last,
      'timestamp': iso,
    };
  }
}
