import '../User.dart';
import 'Admin.dart';

enum Audience { all, students, drivers, admins }
enum PriorityType { low, medium, high }

class NotificationModel {
  final int notificationId; // Java Long -> Dart int
  Admin admin;
  List<User> recipients;
  String title;
  String notificationMessage;
  Audience? audience;
  PriorityType priorityType;
  DateTime createdAt;

  NotificationModel({
    required this.notificationId,
    required this.admin,
    List<User>? recipients,
    required this.title,
    required this.notificationMessage,
    this.audience,
    required this.priorityType,
    DateTime? createdAt,
  })  : recipients = recipients ?? [],
        createdAt = createdAt ?? DateTime.now();

  // JSON serialization/deserialization
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notificationId: json['notificationId'],
      admin: Admin.fromJson(json['admin']),
      recipients: (json['recipients'] as List<dynamic>?)
          ?.map((u) => User.fromJson(u))
          .toList() ??
          [],
      title: json['title'],
      notificationMessage: json['notificationMessage'],
      audience: json['audience'] != null
          ? Audience.values.firstWhere(
              (e) => e.toString() == 'Audience.${json['audience']}')
          : null,
      priorityType: PriorityType.values.firstWhere(
              (e) => e.toString() == 'PriorityType.${json['priorityType']}'),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'notificationId': notificationId,
    'admin': admin.toJson(),
    'recipients': recipients.map((u) => u.toJson()).toList(),
    'title': title,
    'notificationMessage': notificationMessage,
    'audience': audience?.toString().split('.').last,
    'priorityType': priorityType.toString().split('.').last,
    'createdAt': createdAt.toIso8601String(),
  };
}
