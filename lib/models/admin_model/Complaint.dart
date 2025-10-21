import '../User.dart';
import 'Complaint_status.dart';

class Complaint {
  final int complaintId; // Java Long -> Dart int
  User user;
  String subject;
  String description;
  DateTime createdAt;
  ComplaintStatus status;
  // Preserve original JSON payload as a fallback for displaying fields
  final Map<String, dynamic>? raw;

  Complaint({
    required this.complaintId,
    required this.user,
    required this.subject,
    required this.description,
    DateTime? createdAt,
    required this.status,
    this.raw,
  }) : createdAt = createdAt ?? DateTime.now();

  // JSON serialization/deserialization
  factory Complaint.fromJson(Map<String, dynamic> json) {
    // Make a shallow copy to avoid mutating caller map
    final Map<String, dynamic> original = Map<String, dynamic>.from(json);

    int parseId(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      if (v is num) return v.toInt();
      return 0;
    }

    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      try {
        if (v is String) {
          final dt = DateTime.tryParse(v);
          if (dt != null) return dt;
          // try parse numeric string
          final n = int.tryParse(v);
          if (n != null) return DateTime.fromMillisecondsSinceEpoch(n.toString().length <= 10 ? n * 1000 : n);
        }
        if (v is int) {
          return DateTime.fromMillisecondsSinceEpoch(v.toString().length <= 10 ? v * 1000 : v);
        }
        if (v is double) {
          final intVal = v.toInt();
          return DateTime.fromMillisecondsSinceEpoch(intVal.toString().length <= 10 ? intVal * 1000 : intVal);
        }
      } catch (_) {}
      return DateTime.now();
    }

    // Parse status safely; accept either enum name or plain string
    ComplaintStatus parseStatus(dynamic v) {
      try {
        if (v == null) return ComplaintStatus.OPEN;
        final s = v.toString();
        // Accept formats like 'OPEN' or 'ComplaintStatus.OPEN'
        final candidate = s.contains('.') ? s.split('.').last : s;
        return ComplaintStatus.values.firstWhere(
            (e) => e.toString().split('.').last.toUpperCase() == candidate.toUpperCase());
      } catch (_) {
        return ComplaintStatus.OPEN;
      }
    }

    // Ensure user parsing won't crash when user data missing
    Map<String, dynamic> userMap = {};
    try {
      if (json['user'] is Map<String, dynamic>) userMap = Map<String, dynamic>.from(json['user']);
      else if (json['user'] is Map) userMap = Map<String, dynamic>.from(json['user'] as Map);
    } catch (_) {
      userMap = {};
    }

    // If there is no nested user object, attempt to assemble one from top-level fields
    if (userMap.isEmpty) {
      final Map<String, dynamic> top = {};
      // id keys
      final dynamic possibleId = json['userId'] ?? json['user_id'] ?? json['uid'] ?? json['user'] ?? json['createdBy'] ?? json['created_by'] ?? json['reportedBy'] ?? json['reported_by'] ?? json['submittedBy'] ?? json['submitted_by'];
      if (possibleId != null) top['userId'] = possibleId;
      // name fields
      final fn = json['first_name'] ?? json['firstName'] ?? json['name'] ?? json['reported_first_name'] ?? json['reporter_name'];
      final ln = json['last_name'] ?? json['lastName'] ?? json['surname'] ?? json['reported_last_name'] ?? json['reporter_surname'];
      if (fn != null) top['name'] = fn;
      if (ln != null) top['surname'] = ln;
      // email
      if (json['user_email'] != null) top['email'] = json['user_email'];
      else if (json['email'] != null && (json['email'] is String)) top['email'] = json['email'];
      else if (json['reporter_email'] != null) top['email'] = json['reporter_email'];
      else if (json['created_by_email'] != null) top['email'] = json['created_by_email'];
      // role/staff
      if (json['role'] != null) top['role'] = json['role'];
      if (json['staffId'] != null) top['staffId'] = json['staffId'];

      if (top.isNotEmpty) userMap = top;
    }

    // Accept alternate keys for subject/description so UI shows them even when backend varies
    final subjectVal = (json['subject'] ?? json['title'] ?? json['complaint_subject'] ?? json['headline'])?.toString() ?? '';
    final descVal = (json['description'] ?? json['details'] ?? json['body'] ?? json['complaint_body'])?.toString() ?? '';

    return Complaint(
      complaintId: parseId(json['complaintId'] ?? json['id'] ?? json['complaint_id'] ?? json['id_str']),
      user: User.fromJson(userMap),
      subject: subjectVal,
      description: descVal,
      createdAt: parseDate(json['createdAt'] ?? json['created_at'] ?? json['created'] ?? json['createdOn']),
      status: parseStatus(json['status'] ?? json['complaint_status']),
      raw: original,
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
