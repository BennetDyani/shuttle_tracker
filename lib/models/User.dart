import 'Role.dart';

class User {
  final int userId;
  String name;
  String surname;
  String email;
  String? password;
  String? phoneNumber;
  bool disability;
  Role role;
  int? staffId;

  // Keep raw lists for complaints/feedback/notifications if present
  List<dynamic> complaints;
  List<dynamic> feedbacks;
  List<dynamic> notifications;

  User({
    required this.userId,
    required this.name,
    required this.surname,
    required this.email,
    this.password,
    this.phoneNumber,
    required this.disability,
    required this.role,
    this.staffId,
    List<dynamic>? complaints,
    List<dynamic>? feedbacks,
    List<dynamic>? notifications,
  })  : complaints = complaints ?? [],
        feedbacks = feedbacks ?? [],
        notifications = notifications ?? [];

  factory User.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      if (v is num) return v.toInt();
      return 0;
    }

    String roleStr(dynamic r) => r == null ? '' : r.toString();

    Role parseRole(dynamic r) {
      final s = roleStr(r).split('.').last;
      try {
        return Role.values.firstWhere((e) => e.toString().split('.').last == s);
      } catch (_) {
        // fallback: if role strings like 'DISABLED_STUDENT' or 'DISABLED_STUDENT' match
        try {
          return Role.values.firstWhere((e) => e.toString() == 'Role.' + s);
        } catch (_) {
          return Role.STUDENT;
        }
      }
    }

    return User(
      userId: parseId(json['userId'] ?? json['id'] ?? json['uid']),
      name: (json['name'] ?? '').toString(),
      surname: (json['surname'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      password: json['password']?.toString(),
      phoneNumber: json['phoneNumber']?.toString() ?? json['phone']?.toString(),
      disability: (json['disability'] == true || json['disability']?.toString() == 'true'),
      role: parseRole(json['role'] ?? json['roleName'] ?? json['role_name']),
      staffId: json['staffId'] is num ? (json['staffId'] as num).toInt() : (json['staffId'] is String ? int.tryParse(json['staffId']) : null),
      complaints: json['complaints'] as List<dynamic>?,
      feedbacks: json['feedbacks'] as List<dynamic>?,
      notifications: json['notifications'] as List<dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'surname': surname,
    'email': email,
    if (password != null) 'password': password,
    if (phoneNumber != null) 'phoneNumber': phoneNumber,
    'disability': disability,
    'role': role.toString().split('.').last,
    if (staffId != null) 'staffId': staffId,
    'complaints': complaints,
    'feedbacks': feedbacks,
    'notifications': notifications,
  };
}

