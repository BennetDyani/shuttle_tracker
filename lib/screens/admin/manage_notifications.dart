import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shuttle_tracker/services/APIService.dart';
import 'package:shuttle_tracker/models/User.dart' as AppUserModel;
import 'package:shuttle_tracker/services/logger.dart';

class ManageNotificationsScreen extends StatefulWidget {
  const ManageNotificationsScreen({super.key});

  @override
  State<ManageNotificationsScreen> createState() => _ManageNotificationsScreenState();
}

class _ManageNotificationsScreenState extends State<ManageNotificationsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String _audience = 'ALL_DRIVERS';
  String _priority = 'LOW';
  List<int> _recipientIds = [];
  File? _attachment;
  String? _attachmentName;

  final List<String> _audienceOptions = [
    'ALL_DRIVERS',
    'SPECIFIC_DRIVERS',
    'ALL_STUDENTS',
    'DISABLED_STUDENTS',
  ];
  final List<String> _priorityOptions = ['LOW', 'MEDIUM', 'HIGH'];
  List<AppUserModel.User> _drivers = [];
  List<AppUserModel.User> _students = [];
  bool _loadingUsers = false;
  String? _errorLoadingUsers;
  bool _isSending = false;

  // Lightweight cache mapping userId -> display name for notification history
  final Map<int, String> _userNames = {};

  // persisted notifications loaded from backend
  List<Map<String, dynamic>> _notifications = [];
  bool _loadingNotifications = false;
  String? _errorNotifications;

  void _showPreviewDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preview Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title: ${_titleController.text}'),
            const SizedBox(height: 8),
            Text('Message: ${_messageController.text}'),
            const SizedBox(height: 8),
            Text('Audience: $_audience'),
            if (_audience == 'SPECIFIC_DRIVERS')
              Text('Recipients: ${_recipientIds.join(", ")}'),
            const SizedBox(height: 8),
            Text('Priority: $_priority'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAttachment() async {
    // Placeholder for file picker. In a real app, use file_picker or image_picker package.
    // Here, just simulate picking a file.
    setState(() {
      _attachmentName = 'example_attachment.pdf';
      // _attachment = File('path/to/example_attachment.pdf');
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loadingUsers = true;
      _errorLoadingUsers = null;
    });
    try {
      final api = APIService();
      final users = await api.fetchUsers();
      // Split by role for UI convenience
      final drivers = users.where((u) => u.role.toString().contains('DRIVER')).toList();
      final students = users.where((u) => u.role.toString().contains('STUDENT')).toList();
      AppLogger.debug('Loaded users: total=${users.length}, drivers=${drivers.length}, students=${students.length}');
      if (mounted) setState(() {
        _drivers = drivers;
        _students = students;
      });
    } catch (e, st) {
      AppLogger.exception('Failed to load users', e, st);
      if (mounted) setState(() => _errorLoadingUsers = e.toString());
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {});
    final api = APIService();

    try {
      if (_isSending) return; // guard against double-submit
      setState(() => _isSending = true);

      // Determine recipients based on audience
      List<int> targetUserIds = [];
      if (_audience == 'ALL_DRIVERS') {
        // create a notification record per driver
        targetUserIds = _drivers.map((d) => d.userId).toList();
      } else if (_audience == 'ALL_STUDENTS') {
        targetUserIds = _students.map((s) => s.userId).toList();
      } else if (_audience == 'DISABLED_STUDENTS') {
        targetUserIds = _students.where((s) => s.disability).map((s) => s.userId).toList();
      } else if (_audience == 'SPECIFIC_DRIVERS') {
        targetUserIds = _recipientIds;
      }

      if (targetUserIds.isEmpty && _audience != 'SPECIFIC_DRIVERS') {
        // For broad audience but no users loaded, attempt loading
        await _loadUsers();
        // re-evaluate
        if (_audience == 'ALL_DRIVERS') targetUserIds = _drivers.map((d) => d.userId).toList();
        if (_audience == 'ALL_STUDENTS') targetUserIds = _students.map((s) => s.userId).toList();
      }

      // Use the server-side batchCreate endpoint to avoid client-side loops/duplicates.
      if (_audience == 'SPECIFIC_DRIVERS') {
        if (targetUserIds.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one recipient')));
          return;
        }
        final payload = {
          'recipients': targetUserIds,
          'title': _titleController.text,
          'message': _messageController.text,
        };
        await api.post('notifications/batchCreate', payload);
      } else {
        // For broad audiences, let the server resolve recipients by audience
        final payload = {
          'audience': _audience,
          'title': _titleController.text,
          'message': _messageController.text,
          'priority': _priority,
        };
        await api.post('notifications/batchCreate', payload);
      }

      // Refresh persisted notifications from backend and clear form
      await _loadNotifications();
      setState(() {
        _titleController.clear();
        _messageController.clear();
        _audience = 'ALL_DRIVERS';
        _priority = 'LOW';
        _recipientIds = [];
        _attachment = null;
        _attachmentName = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification(s) created')));
    } catch (e, st) {
      AppLogger.exception('Failed to send notification', e, st);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send notification: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Load persisted notifications and users
    _loadNotifications();
    _loadUserNames();
    // Pre-load users so SPECIFIC_DRIVERS recipients are ready when the admin selects that audience
    _loadUsers();
  }

  Future<void> _loadUserNames() async {
    setState(() {
      _loadingUsers = true;
      _errorLoadingUsers = null;
    });
    try {
      final api = APIService();
      final users = await api.fetchUsers();
      final map = <int, String>{};
      for (final u in users) {
        map[u.userId] = '${u.name} ${u.surname}'.trim();
      }
      if (mounted) setState(() => _userNames.addAll(map));
    } catch (e, st) {
      AppLogger.warn('Failed to load user names for notification history', data: e.toString());
      if (mounted) setState(() => _errorLoadingUsers = e.toString());
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _loadNotifications({int? userId, bool? unread}) async {
    setState(() {
      _loadingNotifications = true;
      _errorNotifications = null;
    });
    try {
      final api = APIService();
      final list = await api.fetchNotifications(userId: userId, unread: unread);
      setState(() {
        _notifications = list;
      });
    } catch (e, st) {
      AppLogger.exception('Failed to load notifications', e, st);
      setState(() {
        _errorNotifications = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loadingNotifications = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send and Manage Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/admin/dashboard');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Enter a title' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _messageController,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Enter a message' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _audience,
                    items: _audienceOptions.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => _audience = val);
                      // If admin chooses specific drivers, load users immediately to populate recipients
                      if (val == 'SPECIFIC_DRIVERS' && _drivers.isEmpty && !_loadingUsers) {
                        // fire-and-forget load; UI will show spinner while loading
                        _loadUsers();
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Audience', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _priority,
                    items: _priorityOptions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _priority = val);
                    },
                    decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                  ),
                  if (_audience == 'SPECIFIC_DRIVERS')
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Recipients', border: OutlineInputBorder()),
                        child: _loadingUsers
                            ? const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            : _errorLoadingUsers != null
                                ? Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('Failed to load users: $_errorLoadingUsers'),
                                  )
                                : Wrap(
                                    spacing: 8,
                                    children: _drivers.isEmpty
                                        ? [
                                            const Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: Text('No drivers found'),
                                            )
                                          ]
                                        : _drivers.map((driver) {
                                            final selected = _recipientIds.contains(driver.userId);
                                            return FilterChip(
                                              label: Text('${driver.name} ${driver.surname}'),
                                              selected: selected,
                                              onSelected: (val) {
                                                setState(() {
                                                  if (val) {
                                                    _recipientIds.add(driver.userId);
                                                  } else {
                                                    _recipientIds.remove(driver.userId);
                                                  }
                                                });
                                              },
                                            );
                                          }).toList(),
                                  ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Add Attachment'),
                        onPressed: _pickAttachment,
                      ),
                      if (_attachmentName != null) ...[
                        const SizedBox(width: 10),
                        Text(_attachmentName!, style: const TextStyle(fontSize: 13)),
                      ] else if (_attachment != null) ...[
                        const SizedBox(width: 10),
                        Text('Attachment selected', style: const TextStyle(fontSize: 13)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _isSending
                            ? null
                            : () async {
                                // ensure users are loaded before attempting send when needed
                                if ((_audience == 'SPECIFIC_DRIVERS') && !_loadingUsers && _drivers.isEmpty) {
                                  await _loadUsers();
                                }
                                await _sendNotification();
                              },
                        child: _isSending ? const Text('Sending...') : const Text('Send Notification'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _showPreviewDialog,
                        child: const Text('Preview Message'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('Notification History (persisted)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            if (_loadingNotifications)
              const Center(child: CircularProgressIndicator())
            else if (_errorNotifications != null)
              Padding(padding: const EdgeInsets.all(8.0), child: Text('Failed to load notifications: $_errorNotifications'))
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('Title')),
                    DataColumn(label: Text('User')),
                    DataColumn(label: Text('Message')),
                    DataColumn(label: Text('Read')),
                    DataColumn(label: Text('Created At')),
                  ],
                  rows: _notifications.map((n) {
                    final id = n['notification_id']?.toString() ?? n['notificationId']?.toString() ?? '';
                    final title = n['title']?.toString() ?? '';
                    // try to parse user id as int for lookup
                    int? uidInt;
                    final rawUid = n['user_id'] ?? n['userId'];
                    if (rawUid is int) uidInt = rawUid;
                    else if (rawUid is String) uidInt = int.tryParse(rawUid);
                    final displayUser = uidInt != null ? (_userNames[uidInt] ?? uidInt.toString()) : '';
                    final message = n['message']?.toString() ?? '';
                    final isRead = (n['is_read'] == true || n['isRead'] == true) ? 'Yes' : 'No';
                    final createdAt = n['created_at']?.toString() ?? n['createdAt']?.toString() ?? '';
                    return DataRow(cells: [
                      DataCell(Text(id)),
                      DataCell(Text(title)),
                      DataCell(Text(displayUser)),
                      DataCell(Text(message)),
                      DataCell(Text(isRead)),
                      DataCell(Text(createdAt)),
                    ]);
                  }).toList(),
                ),
              ),
           ],
         ),
       ),
     );
   }
 }
