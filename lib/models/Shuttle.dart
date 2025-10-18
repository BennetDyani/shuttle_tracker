class ShuttleModel {
  final String id;
  final String plate;
  final int? capacity;
  final String? driver;
  final String status;
  final DateTime? lastServiced;
  final String? notes;

  ShuttleModel({
    required this.id,
    required this.plate,
    this.capacity,
    this.driver,
    this.status = 'ACTIVE',
    this.lastServiced,
    this.notes,
  });

  factory ShuttleModel.fromJson(Map<String, dynamic> json) {
    final id = (json['shuttle_id'] ?? json['id'] ?? json['shuttleId'])?.toString() ?? 'S${DateTime.now().millisecondsSinceEpoch}';
    final plate = (json['plate_number'] ?? json['plate'] ?? json['registration'] ?? id).toString();
    final capacityRaw = json['capacity'] ?? json['seats'];
    final capacity = capacityRaw != null ? int.tryParse(capacityRaw.toString()) : null;
    final driver = (json['driver_name'] ?? json['driver'] ?? json['assigned_driver'])?.toString();
    final status = (json['status'] ?? json['shuttle_status'])?.toString().toUpperCase() ?? 'ACTIVE';
    DateTime? lastServed;
    try {
      final ls = json['last_serviced'] ?? json['lastServiced'] ?? json['serviced_at'] ?? json['updated_at'];
      if (ls != null) {
        if (ls is String) lastServed = DateTime.tryParse(ls);
        else if (ls is int) lastServed = DateTime.fromMillisecondsSinceEpoch(ls);
      }
    } catch (_) {}
    final notes = (json['notes'] ?? json['description'])?.toString();

    return ShuttleModel(
      id: id,
      plate: plate.isNotEmpty ? plate : id,
      capacity: capacity,
      driver: driver,
      status: status,
      lastServiced: lastServed,
      notes: notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plate': plate,
      if (capacity != null) 'capacity': capacity,
      if (driver != null) 'driver': driver,
      'status': status,
      if (lastServiced != null) 'last_serviced': lastServiced!.toIso8601String(),
      if (notes != null) 'notes': notes,
    };
  }
}

