import '../User.dart';
import '../Role.dart';

int _parseId(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is String) return int.tryParse(v) ?? 0;
  if (v is num) return v.toInt();
  return 0;
}

User _parseUser(dynamic u) {
  if (u == null) {
    // Return a minimal placeholder user
    return User(
      userId: 0,
      name: '',
      surname: '',
      email: '',
      disability: false,
      role: Role.STUDENT,
    );
  }
  if (u is Map<String, dynamic>) return User.fromJson(u);
  if (u is Map) return User.fromJson(Map<String, dynamic>.from(u));
  // If we get a plain id, create minimal user with that id
  final id = _parseId(u);
  return User(
    userId: id,
    name: '',
    surname: '',
    email: '',
    disability: false,
    role: Role.STUDENT,
  );
}

class Driver {
  final int driverId; // Java Long -> Dart int
  User user;
  String driverLicense;

  Driver({
    required this.driverId,
    required this.user,
    required this.driverLicense,
  });

  // JSON serialization/deserialization
  factory Driver.fromJson(Map<String, dynamic> json) {
    // Accept multiple common id keys from different backends
    final id = _parseId(json['driver_id'] ?? json['driverId'] ?? json['id']);
    final userVal = json['user'] ?? json['user_id'] ?? json['userId'];
    final parsedUser = _parseUser(userVal is Map || userVal is Map<String, dynamic> ? userVal : (json['user'] ?? json['user']));
    final license = (json['driverLicense'] ?? json['driver_license'] ?? json['license_number'] ?? '').toString();
    return Driver(
      driverId: id,
      user: parsedUser,
      driverLicense: license,
    );
  }

  Map<String, dynamic> toJson() => {
    'driverId': driverId,
    'user': user.toJson(),
    'driverLicense': driverLicense,
  };
}
