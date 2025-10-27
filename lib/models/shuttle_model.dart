class Shuttle {
  final int? id;
  final String make;
  final String model;
  final int year;
  final int capacity;
  final String licensePlate;
  final int statusId;
  final int typeId;
  final String? statusName;
  final String? typeName;

  Shuttle({
    this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.capacity,
    required this.licensePlate,
    required this.statusId,
    required this.typeId,
    this.statusName,
    this.typeName,
  });

  factory Shuttle.fromJson(Map<String, dynamic> json) {
    return Shuttle(
      id: json['shuttle_id'] ?? json['shuttleId'] ?? json['id'],
      make: json['make'] ?? json['Make'] ?? '',
      model: json['model'] ?? json['Model'] ?? '',
      year: (json['year'] is int) ? json['year'] : int.tryParse('${json['year']}') ?? 0,
      capacity: (json['capacity'] is int) ? json['capacity'] : int.tryParse('${json['capacity']}') ?? 0,
      licensePlate: json['license_plate'] ?? json['licensePlate'] ?? '',
      statusId: (json['status_id'] is int) ? json['status_id'] : int.tryParse('${json['status_id']}') ?? (json['statusId'] ?? 0),
      typeId: (json['type_id'] is int) ? json['type_id'] : int.tryParse('${json['type_id']}') ?? (json['typeId'] ?? 0),
      statusName: json['status_name'] ?? json['statusName'],
      typeName: json['type_name'] ?? json['typeName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'make': make,
      'model': model,
      'year': year,
      'capacity': capacity,
      'licensePlate': licensePlate,
      'statusId': statusId,
      'typeId': typeId,
    };
  }

  Shuttle copyWith({
    int? id,
    String? make,
    String? model,
    int? year,
    int? capacity,
    String? licensePlate,
    int? statusId,
    int? typeId,
    String? statusName,
    String? typeName,
  }) {
    return Shuttle(
      id: id ?? this.id,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      capacity: capacity ?? this.capacity,
      licensePlate: licensePlate ?? this.licensePlate,
      statusId: statusId ?? this.statusId,
      typeId: typeId ?? this.typeId,
      statusName: statusName ?? this.statusName,
      typeName: typeName ?? this.typeName,
    );
  }
}
