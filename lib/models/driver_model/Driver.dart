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
  final int driverId;
  User user;
  String driverLicense;
  String status;
  String phoneNumber;
  String? licenseNumber;

  Driver({
    required this.driverId,
    required this.user,
    required this.driverLicense,
    this.status = 'Active',
    this.phoneNumber = '',
    this.licenseNumber,
  });

  // JSON serialization/deserialization
  factory Driver.fromJson(Map<String, dynamic> json) {
    // Accept multiple common id keys from different backends
    final id = _parseId(json['driverId'] ?? json['driver_id'] ?? json['id']);
    final user = _parseUser(json['user']);
    final license = (json['driverLicense'] ?? json['driver_license'] ?? '').toString();
    final status = (json['status'] ?? 'Active').toString();
    final phone = (json['phoneNumber'] ?? json['phone_number'] ?? '').toString();
    final licenseNum = (json['licenseNumber'] ?? json['license_number'])?.toString();

    return Driver(
      driverId: id,
      user: user,
      driverLicense: license,
      status: status,
      phoneNumber: phone,
      licenseNumber: licenseNum,
    );
  }

  Map<String, dynamic> toJson() => {
    'driverId': driverId,
    'user': user.toJson(),
    'driverLicense': driverLicense,
    'status': status,
    'phoneNumber': phoneNumber,
    'licenseNumber': licenseNumber,
  };
}
