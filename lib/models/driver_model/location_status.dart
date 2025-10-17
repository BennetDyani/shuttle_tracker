
enum LocationStatus {
  AT_CAMPUS,
  DEPARTING_CAMPUS,
  ON_ROUTE_TO_RESIDENCE,
  AT_RESIDENCE,
  RETURNING_TO_CAMPUS,
}

extension LocationStatusExtension on LocationStatus {
  String get label {
    switch (this) {
      case LocationStatus.AT_CAMPUS:
        return "At Campus";
      case LocationStatus.DEPARTING_CAMPUS:
        return "Departing Campus";
      case LocationStatus.ON_ROUTE_TO_RESIDENCE:
        return "On Route to Residence";
      case LocationStatus.AT_RESIDENCE:
        return "At Residence";
      case LocationStatus.RETURNING_TO_CAMPUS:
        return "Returning to Campus";
    }
  }

  String get colorCode {
    switch (this) {
      case LocationStatus.AT_CAMPUS:
        return "#4CAF50"; // Green
      case LocationStatus.DEPARTING_CAMPUS:
        return "#FF9800"; // Orange
      case LocationStatus.ON_ROUTE_TO_RESIDENCE:
        return "#2196F3"; // Blue
      case LocationStatus.AT_RESIDENCE:
        return "#9C27B0"; // Purple
      case LocationStatus.RETURNING_TO_CAMPUS:
        return "#FFC107"; // Amber
    }
  }

  static LocationStatus fromString(String status) {
    return LocationStatus.values.firstWhere(
          (e) => e.toString().split('.').last == status,
      orElse: () => LocationStatus.AT_CAMPUS,
    );
  }
}
