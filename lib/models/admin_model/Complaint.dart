
import '../User.dart';
import 'Complaint_status.dart';

class Complaint {
  final int complaintId; // Java Long -> Dart int
  User user;
  String subject;
  String description;
  DateTime createdAt;
  ComplaintStatus status;

  Complaint({
    required this.complaintId,
    required this.user,
    required this.subject,
    required this.description,
    DateTime? createdAt,
    required this.status,
  }) : createdAt = createdAt ?? DateTime.now();

  // JSON serialization/deserialization
  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      complaintId: json['complaintId'],
      user: User.fromJson(json['user']),
      subject: json['subject'],
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt']),
      status: ComplaintStatus.values.firstWhere(
              (e) => e.toString() == 'ComplaintStatus.${json['status']}'),
    );
  }

  Map<String, dynamic> toJson() => {
    'complaintId': complaintId,
    'user': user.toJson(),
    'subject': subject,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'status': status.toString().split('.').last,
  };
}
