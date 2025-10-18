import 'Role.dart';
import 'admin_model/Complaint.dart';
import 'admin_model/Notification.dart';
import 'Feedback.dart';

class User {
  final int userId;
  final String name;
  final String surname;
  final String email;
  final String password;
  final String phoneNumber;
  final bool disability;
  final Role role;
  final int? staffId;



  List<Complaint> complaints;
  List<FeedbackModel> feedbacks;
  List<NotificationModel> notifications;

  User({
    required this.userId,
    required this.name,
    required this.surname,
    required this.email,
    required this.password,
    required this.phoneNumber,
    required this.disability,
    required this.role,
    this.staffId,

    List<Complaint>? complaints,
    List<FeedbackModel>? feedbacks,
    List<NotificationModel>? notifications,
  })  : complaints = complaints ?? [],
        feedbacks = feedbacks ?? [],
        notifications = notifications ?? [];

  // JSON serialization/deserialization (useful for APIs)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: (json['userId'] as num).toInt(),
      name: json['name'],
      surname: json['surname'],
      email: json['email'] as String,
      password: json['password'],
      phoneNumber: json['phoneNumber'],
      disability: json['disability'] ?? false,
      role: Role.values.firstWhere((r) => r.toString() == 'Role.${json['role']}'),
      staffId: json['staffId'] as int?,
      complaints: (json['complaints'] as List<dynamic>?)
          ?.map((c) => Complaint.fromJson(c))
          .toList() ??
          [],
      feedbacks: (json['feedbacks'] as List<dynamic>?)
          ?.map((f) => FeedbackModel.fromJson(f))
          .toList() ??
          [],
      notifications: (json['notifications'] as List<dynamic>?)
          ?.map((n) => NotificationModel.fromJson(n))
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'surname': surname,
    'email': email,
    'password': password,
    'phoneNumber': phoneNumber,
    'disability': disability,
    'role': role.toString().split('.').last,
    if (staffId != null) 'staffId': staffId,
    'complaints': complaints.map((c) => c.toJson()).toList(),
    'feedbacks': feedbacks.map((f) => f.toJson()).toList(),
    'notifications': notifications.map((n) => n.toJson()).toList(),
  };
}