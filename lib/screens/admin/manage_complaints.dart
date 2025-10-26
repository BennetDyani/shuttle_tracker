import 'package:flutter/material.dart';
import 'package:shuttle_tracker/services/APIService.dart';
import 'package:shuttle_tracker/services/endpoints.dart';
import 'package:shuttle_tracker/models/admin_model/Complaint.dart';
import 'package:shuttle_tracker/services/logger.dart';
import 'dart:convert';

// This screen previously used a hard-coded mock list of complaints which caused
// the dashboard summary counts to differ from the complaints list. Replace the
// static list with a real API-backed fetch so the UI is consistent with the
// counts shown on the Admin dashboard.

class ManageComplaintsScreen extends StatefulWidget {
  const ManageComplaintsScreen({super.key});

  @override
  State<ManageComplaintsScreen> createState() => _ManageComplaintsScreenState();
}

class _ManageComplaintsScreenState extends State<ManageComplaintsScreen> {
  List<dynamic> _complaints = [];
  bool _isLoading = true;
  String? _error;

  final List<String> statusOptions = ['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'];

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }

  Future<void> _fetchComplaints() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _complaints = [];
    });
    try {
      final api = APIService();
      final res = await api.get(Endpoints.complaintGetAll);
      dynamic list = res;
      if (res is Map<String, dynamic>) {
        if (res['data'] is List) list = res['data'];
        else if (res['complaints'] is List) list = res['complaints'];
      }
      if (list is List) {
        final parsed = <dynamic>[];
        for (final item in list) {
          try {
            if (item is Map<String, dynamic>) parsed.add(Complaint.fromJson(item));
            else if (item is Map) parsed.add(Complaint.fromJson(Map<String, dynamic>.from(item)));
            else parsed.add(item);
          } catch (e) {
            // If parsing into model fails, keep raw map as fallback
            AppLogger.warn('Failed to parse complaint into model', data: e.toString());
            parsed.add(item);
          }
        }
        AppLogger.debug('Fetched complaints', data: {'count': parsed.length});
        setState(() {
          _complaints = parsed;
        });
        // If the returned list is suspiciously small, attempt to fetch with a large pageSize to handle paginated backends
        if (parsed.length <= 1) {
          try {
            AppLogger.debug('Complaints list small; retrying with pageSize=1000');
            final res2 = await APIService().get('${Endpoints.complaintGetAll}?pageSize=1000');
            dynamic list2 = res2;
            if (res2 is Map<String, dynamic>) {
              if (res2['data'] is List) list2 = res2['data'];
              else if (res2['complaints'] is List) list2 = res2['complaints'];
            }
            if (list2 is List) {
              final parsed2 = <dynamic>[];
              for (final item in list2) {
                try {
                  if (item is Map<String, dynamic>) parsed2.add(Complaint.fromJson(item));
                  else if (item is Map) parsed2.add(Complaint.fromJson(Map<String, dynamic>.from(item)));
                  else parsed2.add(item);
                } catch (e) {
                  parsed2.add(item);
                }
              }
              AppLogger.debug('Fetched complaints (retry)', data: {'count': parsed2.length});
              setState(() => _complaints = parsed2);
            }
          } catch (e) {
            AppLogger.warn('Retry fetch for complaints failed', data: e.toString());
          }
        }
      } else {
        setState(() => _error = 'No complaints found');
      }
    } catch (e, st) {
      AppLogger.exception('Failed to fetch complaints', e, st);
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showComplaintDetails(dynamic complaint) {
    // Normalize helpers to read fields from either Complaint model or raw Map
    String id = _getComplaintId(complaint).toString();
    String rawStatus = _getStatus(complaint);
    // Use nullable status for the dropdown; if the raw status is not one of the known options, start as null
    String? status = statusOptions.contains(rawStatus) && rawStatus.isNotEmpty ? rawStatus : null;
    String adminNotes = _getAdminNotes(complaint) ?? '';
    final TextEditingController responseController = TextEditingController();
    final TextEditingController notesController = TextEditingController(text: adminNotes);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Log the complaint payload to help debug missing fields
            try {
              final payload = (complaint is Complaint) ? (complaint.raw ?? complaint.toJson()) : complaint;
              AppLogger.debug('Opening complaint details', data: payload);
            } catch (_) {}
            return AlertDialog(
              title: Text('Complaint #$id'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('User: ${_getUserName(complaint)}'),
                    Text('Email: ${_getUserEmail(complaint)}'),
                    // If key fields missing, show a button to inspect raw payload
                    if ((_getUserEmail(complaint).isEmpty || _getSubject(complaint).isEmpty))
                      TextButton(
                        onPressed: () {
                          final payload = (complaint is Complaint) ? (complaint.raw ?? complaint.toJson()) : complaint;
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Raw complaint payload'),
                              content: SingleChildScrollView(child: Text(_prettyJson(payload ?? {}))),
                              actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
                            ),
                          );
                        },
                        child: const Text('Show raw payload', style: TextStyle(fontSize: 12)),
                      ),
                    const SizedBox(height: 12),
                    const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(_getDescription(complaint)),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      // When status is null or not in the known options, value must be null to avoid the Dropdown assertion
                      initialValue: (status != null && statusOptions.contains(status)) ? status : null,
                      hint: const Text('Select status'),
                      isExpanded: true,
                      items: statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) {
                        setModalState(() => status = val);
                      },
                      decoration: const InputDecoration(labelText: 'Status'),
                    ),
                    const SizedBox(height: 10),
                    const Text('Admin Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(hintText: 'Attach admin notes...', border: OutlineInputBorder()),
                      onChanged: (val) {
                        setModalState(() => adminNotes = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text('Responses:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._getResponses(complaint).map((r) => Padding(padding: const EdgeInsets.symmetric(vertical: 2.0), child: Text('- $r', style: const TextStyle(fontSize: 13)))),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: responseController,
                            decoration: const InputDecoration(hintText: 'Add response...', border: OutlineInputBorder()),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.blue),
                          onPressed: () async {
                            final text = responseController.text.trim();
                            if (text.isNotEmpty) {
                              // Optionally call API to append response; for now update local state and close.
                              setState(() {
                                _appendResponse(complaint, text);
                              });
                              responseController.clear();
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Response added')));
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
                ElevatedButton(
                  onPressed: () async {
                    // Save changes: update status and admin notes via API if possible
                    // If status is still null (unknown), fall back to OPEN to avoid sending empty values
                    final newStatus = (status == null || status!.isEmpty) ? 'OPEN' : status!;
                    final newNotes = notesController.text;
                    final cid = _getComplaintId(complaint);
                    final oldStatus = _getStatus(complaint);
                    setState(() => _setStatus(complaint, newStatus));
                    try {
                      await APIService().put(Endpoints.complaintUpdate, {'complaintId': cid, 'status': newStatus, 'adminNotes': newNotes});
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
                    } catch (e) {
                      AppLogger.warn('Failed to update complaint', data: e.toString());
                      // revert on failure
                      setState(() => _setStatus(complaint, oldStatus));
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Helpers to handle Complaint model or raw Map interchangeably ---
  dynamic _getComplaintByIndex(int index) => _complaints[index];
  dynamic _getComplaintId(dynamic c) {
    try {
      if (c is Complaint) return c.complaintId;
      if (c is Map) {
        dynamic v = c['complaintId'] ?? c['complaint_id'] ?? c['id'] ?? c['id_str'] ?? c['cid'];
        if (v == null) return 0;
        if (v is int) return v;
        if (v is String) return int.tryParse(v) ?? v;
        if (v is num) return v.toInt();
        return v.toString();
      }
    } catch (_) {}
    return 0;
  }

  String _getUserEmail(dynamic c) {
    try {
      if (c is Complaint) {
        final email = c.user.email;
        if (email.isNotEmpty) return email;
        // fallback to raw JSON if available
        if (c.raw != null) {
          final raw = c.raw!;
          if (raw['user'] is Map) {
            final u = raw['user'] as Map;
            final e = u['email'] ?? u['user_email'] ?? u['emailAddress'] ?? u['contact_email'];
            if (e != null && e.toString().isNotEmpty) return e.toString();
          }
          final keys = ['user_email', 'email', 'emailAddress', 'userEmail', 'contact_email'];
          for (final k in keys) {
            if (raw.containsKey(k) && raw[k] != null && raw[k].toString().isNotEmpty) return raw[k].toString();
          }
        }
      }
      if (c is Map) {
        // Common keys
        final keys = ['user', 'user_email', 'email', 'emailAddress', 'userEmail', 'userEmailAddress', 'contact_email'];
        // If there's a nested user map, prefer that
        if (c['user'] is Map) {
          final u = c['user'] as Map;
          final e = u['email'] ?? u['user_email'] ?? u['emailAddress'] ?? u['contact_email'];
          if (e != null && e.toString().isNotEmpty) return e.toString();
        }
        for (final k in keys) {
          if (c.containsKey(k) && c[k] != null && c[k].toString().isNotEmpty) return c[k].toString();
        }
        // fallback: maybe user object is stringified
        if (c['user'] != null && c['user'] is String) {
          final s = c['user'] as String;
          if (s.contains('@')) return s;
        }
        // Last-resort: search recursively for any likely key
        try {
          final found = _searchMapForKeys(c, ['user_email', 'email', 'contact_email', 'emailAddress', 'userEmail']);
          if (found != null) return found;
        } catch (_) {}
      }
    } catch (_) {}
    return '';
  }

  String _getUserName(dynamic c) {
    try {
      if (c is Complaint) {
        final name = '${c.user.name} ${c.user.surname}'.trim();
        if (name.isNotEmpty) return name;
        // fallback to raw
        if (c.raw != null) {
          final raw = c.raw!;
          if (raw['user'] is Map) {
            final u = raw['user'] as Map;
            final first = u['first_name'] ?? u['firstName'] ?? u['name'] ?? u['givenName'];
            final last = u['last_name'] ?? u['lastName'] ?? u['surname'] ?? u['familyName'];
            final combined = ('${first ?? ''} ${last ?? ''}').trim();
            if (combined.isNotEmpty) return combined;
            final full = u['fullName'] ?? u['fullname'] ?? u['displayName'];
            if (full != null && full.toString().isNotEmpty) return full.toString();
          }
          final first = raw['first_name'] ?? raw['firstName'] ?? raw['name'] ?? raw['givenName'];
          final last = raw['last_name'] ?? raw['lastName'] ?? raw['surname'] ?? raw['familyName'];
          final combined = ('${first ?? ''} ${last ?? ''}').trim();
          if (combined.isNotEmpty) return combined;
          final alt = raw['userName'] ?? raw['user_name'] ?? raw['fullName'] ?? raw['fullname'] ?? raw['displayName'];
          if (alt != null && alt.toString().isNotEmpty) return alt.toString();
        }
      }
      if (c is Map) {
        // Nested user map
        final u = c['user'];
        if (u is Map) {
          final first = u['first_name'] ?? u['firstName'] ?? u['name'] ?? u['givenName'];
          final last = u['last_name'] ?? u['lastName'] ?? u['surname'] ?? u['familyName'];
          final combined = ('${first ?? ''} ${last ?? ''}').trim();
          if (combined.isNotEmpty) return combined;
          final full = u['fullName'] ?? u['fullname'] ?? u['displayName'];
          if (full != null && full.toString().isNotEmpty) return full.toString();
        }
        // Top-level variants
        final first = c['first_name'] ?? c['firstName'] ?? c['name'] ?? c['givenName'];
        final last = c['last_name'] ?? c['lastName'] ?? c['surname'] ?? c['familyName'];
        final combined = ('${first ?? ''} ${last ?? ''}').trim();
        if (combined.isNotEmpty) return combined;
        final alt = c['userName'] ?? c['user_name'] ?? c['fullName'] ?? c['fullname'] ?? c['displayName'];
        if (alt != null && alt.toString().isNotEmpty) return alt.toString();
      }
    } catch (_) {}
    return '';
  }

  // --- Reusable extractors (placed before usages) ---
  String _extractStudentNumberFromMap(Map<dynamic, dynamic> map) {
    try {
      final keys = ['studentNumber', 'student_number', 'student_no', 'studentId', 'student_id', 'regNo', 'registration_number', 'stud_no', 'studentNo', 'registration_no'];
      if (map['user'] is Map) {
        final u = map['user'] as Map;
        for (final k in keys) {
          if (u.containsKey(k) && u[k] != null && u[k].toString().isNotEmpty) return u[k].toString();
        }
        final found = _searchMapForKeys(u, keys);
        if (found != null && found.isNotEmpty) return found;
      }
      for (final k in keys) {
        if (map.containsKey(k) && map[k] != null && map[k].toString().isNotEmpty) return map[k].toString();
      }
      final found = _searchMapForKeys(map, keys);
      if (found != null && found.isNotEmpty) return found;
    } catch (_) {}
    return '';
  }

  String _extractUserIdFromMap(Map<dynamic, dynamic> map) {
    try {
      final keys = ['userId', 'user_id', 'uid', 'id', 'createdBy', 'created_by', 'reportedBy', 'reported_by', 'staffId', 'staff_id', 'accountId'];
      if (map['user'] is Map) {
        final u = map['user'] as Map;
        for (final k in keys) {
          if (u.containsKey(k) && u[k] != null && u[k].toString().isNotEmpty) return u[k].toString();
        }
        final found = _searchMapForKeys(u, keys);
        if (found != null && found.isNotEmpty) return found;
      }
      for (final k in keys) {
        if (map.containsKey(k) && map[k] != null && map[k].toString().isNotEmpty) return map[k].toString();
      }
      final found = _searchMapForKeys(map, keys);
      if (found != null && found.isNotEmpty) return found;
    } catch (_) {}
    return '';
  }

  // Extract a student number or registration number from the complaint or raw payload
  String _getStudentNumber(dynamic c) {
    try {
      // Prefer structured/raw payload search using a dedicated extractor
      if (c is Complaint) {
        if (c.raw != null) {
          final found = _extractStudentNumberFromMap(c.raw!);
          if (found.isNotEmpty) return found;
        }
        // If the model held a user map-like structure, try that as well via raw
        try {
          final fallback = _searchMapForKeys(c.toJson(), ['studentNumber', 'student_number', 'student_no', 'studentId', 'student_id', 'regNo', 'registration_number', 'stud_no']);
          if (fallback != null && fallback.isNotEmpty) return fallback;
        } catch (_) {}
      }

      if (c is Map) {
        final found = _extractStudentNumberFromMap(c);
        if (found.isNotEmpty) return found;
      }
    } catch (_) {}
    return '';
  }

  // Extract user id from model/raw payload
  String _getUserId(dynamic c) {
    try {
      // If Complaint model, check model's user first then raw
      if (c is Complaint) {
        try {
          final uid = c.user.userId;
          if (uid != 0) return uid.toString();
        } catch (_) {}
        if (c.raw != null) {
          final found = _extractUserIdFromMap(c.raw!);
          if (found.isNotEmpty) return found;
        }
        // fallback: check toJson representation
        try {
          final fallback = _searchMapForKeys(c.toJson(), ['userId', 'user_id', 'uid', 'id', 'createdBy', 'created_by', 'reportedBy', 'reported_by']);
          if (fallback != null && fallback.isNotEmpty) return fallback;
        } catch (_) {}
      }

      if (c is Map) {
        final found = _extractUserIdFromMap(c);
        if (found.isNotEmpty) return found;
      }
    } catch (_) {}
    return '';
  }

  // Final fallback: search many likely keys in the raw payload to find any user identifier
  String _getAnyUserIdentifier(dynamic c) {
    try {
      if (c is Complaint) {
        if (c.raw != null) {
          final raw = c.raw!;
          final keys = [
            'email', 'user_email', 'reporter_email', 'created_by_email', 'student_email', 'contact_email',
            'studentNumber', 'student_number', 'student_no', 'studentId', 'student_id', 'regNo', 'registration_number',
            'id', 'uid', 'userId', 'user_id', 'staffId', 'staff_id'
          ];
          final found = _searchMapForKeys(raw, keys);
          if (found != null && found.isNotEmpty) return found;
        }
        // fallback: inspect the model's toJson representation as a Map
        try {
          final found = _searchMapForKeys(c.toJson(), ['email','user_email','studentNumber','student_number','id','uid','userId']);
          if (found != null && found.isNotEmpty) return found;
        } catch (_) {}
      }

      if (c is Map) {
        final keys = [
          'email', 'user_email', 'reporter_email', 'created_by_email', 'student_email', 'contact_email',
          'studentNumber', 'student_number', 'student_no', 'studentId', 'student_id', 'regNo', 'registration_number',
          'id', 'uid', 'userId', 'user_id', 'staffId', 'staff_id'
        ];
        final found = _searchMapForKeys(c, keys);
        if (found != null && found.isNotEmpty) return found;
      }
    } catch (_) {}
    return '';
  }

  String _getSubject(dynamic c) {
    try {
      if (c is Complaint) {
        if (c.subject.isNotEmpty) return c.subject;
        if (c.raw != null) {
          final raw = c.raw!;
          final keys = ['subject', 'title', 'complaint_subject', 'headline', 'headline_text', 'subject_text'];
          for (final k in keys) {
            if (raw.containsKey(k) && raw[k] != null && raw[k].toString().isNotEmpty) return raw[k].toString();
          }
          if (raw['complaint'] is Map) {
            final comp = raw['complaint'] as Map;
            for (final k in ['subject', 'title']) {
              if (comp.containsKey(k) && comp[k] != null && comp[k].toString().isNotEmpty) return comp[k].toString();
            }
          }
        }
      }
      if (c is Map) {
        final keys = ['subject', 'title', 'complaint_subject', 'headline', 'headline_text', 'subject_text'];
        for (final k in keys) {
          if (c.containsKey(k) && c[k] != null && c[k].toString().isNotEmpty) return c[k].toString();
        }
        // sometimes subject is nested inside a 'complaint' object
        if (c['complaint'] is Map) {
          final comp = c['complaint'] as Map;
          for (final k in ['subject', 'title']) {
            if (comp.containsKey(k) && comp[k] != null && comp[k].toString().isNotEmpty) return comp[k].toString();
          }
        }
        // Last-resort: recursive search
        try {
          final found = _searchMapForKeys(c, ['subject', 'title', 'headline']);
          if (found != null) return found;
        } catch (_) {}
      }
    } catch (_) {}
    return '';
  }

  String _getStatus(dynamic c) {
    try {
      if (c is Complaint) return c.status.toString().split('.').last;
      if (c is Map) return (c['status'] ?? c['complaint_status'] ?? '')?.toString() ?? '';
    } catch (_) {}
    return '';
  }

  void _setStatus(dynamic c, String status) {
    try {
      if (c is Complaint) {
        // No setter on model; mutate via reflection not possible, so replace model in list
        final idx = _complaints.indexOf(c);
        if (idx != -1) {
          // create new Complaint with updated status
          try {
            final map = c.toJson();
            map['status'] = status;
            _complaints[idx] = Complaint.fromJson(Map<String, dynamic>.from(map));
          } catch (_) {
            // fallback: leave original
          }
        }
        return;
      }
      if (c is Map) c['status'] = status;
    } catch (_) {}
  }

  String _getCreatedAt(dynamic c) {
    try {
      if (c is Complaint) return c.createdAt.toIso8601String();
      if (c is Map) return c['createdAt'] ?? c['created_at'] ?? c['created'] ?? '';
    } catch (_) {}
    return '';
  }

  String _getDescription(dynamic c) {
    try {
      if (c is Complaint) {
        if (c.description.isNotEmpty) return c.description;
        if (c.raw != null) {
          final raw = c.raw!;
          final keys = ['description', 'details', 'body', 'complaint_body', 'message', 'text'];
          for (final k in keys) {
            if (raw.containsKey(k) && raw[k] != null && raw[k].toString().isNotEmpty) return raw[k].toString();
          }
          if (raw['complaint'] is Map) {
            final comp = raw['complaint'] as Map;
            for (final k in ['description', 'details', 'body']) {
              if (comp.containsKey(k) && comp[k] != null && comp[k].toString().isNotEmpty) return comp[k].toString();
            }
          }
        }
      }
      if (c is Map) {
        final keys = ['description', 'details', 'body', 'complaint_body', 'message', 'text'];
        for (final k in keys) {
          if (c.containsKey(k) && c[k] != null && c[k].toString().isNotEmpty) return c[k].toString();
        }
        // Last-resort: recursive search
        try {
          final found = _searchMapForKeys(c, ['description', 'details', 'body', 'message', 'text']);
          if (found != null) return found;
        } catch (_) {}
      }
    } catch (_) {}
    return '';
  }

  List<String> _getResponses(dynamic c) {
    try {
      if (c is Complaint) return <String>[]; // model currently has no responses field
      if (c is Map) {
        final r = c['responses'];
        if (r is List) return r.map((e) => e?.toString() ?? '').toList();
      }
    } catch (_) {}
    return <String>[];
  }

  String? _getAdminNotes(dynamic c) {
    try {
      if (c is Complaint) return null; // model lacks adminNotes field
      if (c is Map) return c['adminNotes'] ?? c['admin_notes'] ?? '';
    } catch (_) {}
    return null;
  }

  void _appendResponse(dynamic c, String text) {
    try {
      if (c is Map) {
        c['responses'] = (c['responses'] as List<dynamic>?) ?? <dynamic>[];
        c['responses'].add(text);
      } else {
        // For model-backed complaint we don't persist responses here; could call API
      }
    } catch (_) {}
  }

  Future<void> _updateComplaintStatus(dynamic c, String status) async {
    final cid = _getComplaintId(c);
    final oldStatus = _getStatus(c);
    setState(() => _setStatus(c, status));
    try {
      await APIService().put(Endpoints.complaintUpdate, {'complaintId': cid, 'status': status});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Complaint $cid updated to $status')));
    } catch (e) {
      AppLogger.warn('Failed to update complaint status', data: e.toString());
      // revert
      setState(() => _setStatus(c, oldStatus));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    }
  }

  // Recursive search helper: look for the first string value for any of the provided keys (case-insensitive)
  String? _searchMapForKeys(Map<dynamic, dynamic> map, List<String> keys) {
    try {
      for (final entry in map.entries) {
        final k = entry.key?.toString() ?? '';
        final v = entry.value;
        for (final candidate in keys) {
          if (k.toLowerCase() == candidate.toLowerCase() && v != null && v.toString().isNotEmpty) return v.toString();
        }
      }
      // Recurse into nested maps/lists
      for (final entry in map.entries) {
        final v = entry.value;
        if (v is Map) {
          final found = _searchMapForKeys(v, keys);
          if (found != null && found.isNotEmpty) return found;
        } else if (v is List) {
          for (final item in v) {
            if (item is Map) {
              final found = _searchMapForKeys(item, keys);
              if (found != null && found.isNotEmpty) return found;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // Pretty-print any dynamic payload (Map, Complaint, JSON string) safely
  String _prettyJson(dynamic payload) {
    try {
      if (payload == null) return 'null';
      if (payload is Complaint) payload = payload.raw ?? payload.toJson();
      if (payload is String) {
        // attempt to decode string JSON
        try {
          final parsed = jsonDecode(payload);
          if (parsed is Map) payload = parsed;
        } catch (_) {}
      }
      if (payload is Map) {
        final map = <String, dynamic>{};
        payload.forEach((k, v) => map[k.toString()] = v);
        return const JsonEncoder.withIndent('  ').convert(map);
      }
      return payload.toString();
    } catch (_) {
      try {
        return payload.toString();
      } catch (_) {
        return 'Invalid payload';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints Center'),
        leading: Navigator.canPop(context) ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)) : null,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchComplaints, tooltip: 'Refresh'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        onPressed: _fetchComplaints,
                      ),
                    ],
                  ),
                )
              : _complaints.isEmpty
                  ? const Center(child: Text('No complaints found'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        return SingleChildScrollView(
                          padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total: ${_complaints.length} complaints',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isMobile ? 16 : 18,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (isMobile)
                                // Mobile: Card view
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _complaints.length,
                                  itemBuilder: (context, index) {
                                    return _buildMobileComplaintCard(index);
                                  },
                                )
                              else
                                // Desktop: Table view
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: _buildDesktopComplaintTable(),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _buildMobileComplaintCard(int index) {
    final c = _getComplaintByIndex(index);
    final email = _getUserEmail(c);
    final studentNo = _getStudentNumber(c);
    final name = _getUserName(c);
    final uid = _getUserId(c);
    String userDisplay = (email.isNotEmpty)
        ? email
        : (studentNo.isNotEmpty)
            ? studentNo
            : (name.isNotEmpty)
                ? name
                : (uid.isNotEmpty ? uid : 'Unknown');
    if (userDisplay == 'Unknown') {
      final any = _getAnyUserIdentifier(c);
      if (any.isNotEmpty) userDisplay = any;
    }

    final status = _getStatus(c);
    final statusColor = status.toUpperCase() == 'RESOLVED' || status.toUpperCase() == 'CLOSED'
        ? Colors.green
        : status.toUpperCase() == 'IN_PROGRESS'
            ? Colors.orange
            : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _showComplaintDetails(c),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#${_getComplaintId(c)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _getSubject(c),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      userDisplay,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(_getCreatedAt(c)),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                    onPressed: () => _showComplaintDetails(c),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopComplaintTable() {
    return DataTable(
      columns: const [
        DataColumn(label: Text('ID')),
        DataColumn(label: Text('User')),
        DataColumn(label: Text('Subject')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Created')),
        DataColumn(label: Text('Actions')),
      ],
      rows: List<DataRow>.generate(_complaints.length, (index) {
        final c = _getComplaintByIndex(index);
        final email = _getUserEmail(c);
        final studentNo = _getStudentNumber(c);
        final name = _getUserName(c);
        final uid = _getUserId(c);
        String userDisplay = (email.isNotEmpty)
            ? email
            : (studentNo.isNotEmpty)
                ? studentNo
                : (name.isNotEmpty)
                    ? name
                    : (uid.isNotEmpty ? uid : 'Unknown');
        if (userDisplay == 'Unknown') {
          final any = _getAnyUserIdentifier(c);
          if (any.isNotEmpty) userDisplay = any;
        }

        return DataRow(cells: [
          DataCell(Text('#${_getComplaintId(c)}')),
          DataCell(Text(userDisplay)),
          DataCell(SizedBox(width: 200, child: Text(_getSubject(c), overflow: TextOverflow.ellipsis))),
          DataCell(Text(_getStatus(c))),
          DataCell(Text(_formatDate(_getCreatedAt(c)))),
          DataCell(
            TextButton.icon(
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('View'),
              onPressed: () => _showComplaintDetails(c),
            ),
          ),
        ]);
      }),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}
