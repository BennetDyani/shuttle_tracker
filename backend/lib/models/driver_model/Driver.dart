import '../User.dart';

class Driver {
  final String driverId;
  User user;
  String driverLicense;

  Driver({
    required this.driverId,
    required this.user,
    required this.driverLicense,
  });

  Driver copyWith({
    String? driverId,
    User? user,
    String? driverLicense,
  }) {
    return Driver(
      driverId: driverId ?? this.driverId,
      user: user ?? this.user,
      driverLicense: driverLicense ?? this.driverLicense,
    );
  }

  // JSON serialization/deserialization
  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      driverId: json['driverId'],
      user: User.fromJson(json['user']),
      driverLicense: json['driverLicense'],
    );
  }

  Map<String, dynamic> toJson() => {
    'driverId': driverId,
    'user': user.toJson(),
    'driverLicense': driverLicense,
  };
}
