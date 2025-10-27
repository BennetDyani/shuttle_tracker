class Stop {
  final int? stopId;
  final int routeId;
  String name;
  double latitude;
  double longitude;
  int order;

  Stop({
    this.stopId,
    required this.routeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.order,
  });

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      stopId: json['stop_id'] ?? json['stopId'] ?? json['id'],
      routeId: json['route_id'] ?? json['routeId'] ?? 0,
      name: json['name'] ?? '',
      latitude: (json['latitude'] is num) ? (json['latitude'] as num).toDouble() : double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0,
      longitude: (json['longitude'] is num) ? (json['longitude'] as num).toDouble() : double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0,
      order: json['order'] ?? json['stop_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (stopId != null) 'stop_id': stopId,
      'route_id': routeId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'order': order,
    };
  }

  Stop copyWith({
    int? stopId,
    int? routeId,
    String? name,
    double? latitude,
    double? longitude,
    int? order,
  }) {
    return Stop(
      stopId: stopId ?? this.stopId,
      routeId: routeId ?? this.routeId,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      order: order ?? this.order,
    );
  }
}

