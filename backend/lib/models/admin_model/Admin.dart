import '../User.dart';

class Admin {
  final int adminId; // Java Long -> Dart int
  User user;

  Admin({
    required this.adminId,
    required this.user,
  });

  // JSON serialization/deserialization
  factory Admin.fromJson(Map<String, dynamic> json) {
    return Admin(
      adminId: json['adminId'],
      user: User.fromJson(json['user']),
    );
  }

  Map<String, dynamic> toJson() => {
    'adminId': adminId,
    'user': user.toJson(),
  };
}
