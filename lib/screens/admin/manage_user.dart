import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shuttle_tracker/services/APIService.dart';
import 'package:shuttle_tracker/services/logger.dart';

// Mock user model (kept for UI-level state; server-backed creates real user)
class User {
  final String id;
  String name;
  String email;
  String role; // STUDENT, DRIVER, ADMIN
  String status; // ACTIVE, SUSPENDED, RESIGNED
  bool isDisabled; // For students
  String? phone;
  String? license;
  String? shuttle;
  DateTime? suspensionDate;
  String? suspensionReason;
  String? actionedBy;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.isDisabled = false,
    this.phone,
    this.license,
    this.shuttle,
    this.suspensionDate,
    this.suspensionReason,
    this.actionedBy,
  });
}

class ManageUserScreen extends StatefulWidget {
  const ManageUserScreen({Key? key}) : super(key: key);

  @override
  State<ManageUserScreen> createState() => _ManageUserScreenState();
}

class _ManageUserScreenState extends State<ManageUserScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loadingUsers = true;
  String? _loadingError;
  String? _lastUsersRawJson;
  // Start with an empty list; we'll populate from the backend on init
  final List<User> users = [];
  String roleFilter = 'ALL';
  String statusFilter = 'ALL';
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Fetch real users from the backend when the screen initializes
    _fetchUsers();
  }

  // Helper to parse dates from API values (ISO string or epoch)
  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try {
      if (v is String) return DateTime.tryParse(v);
      if (v is int) {
        // seconds vs milliseconds heuristic
        return v.toString().length <= 10
            ? DateTime.fromMillisecondsSinceEpoch(v * 1000)
            : DateTime.fromMillisecondsSinceEpoch(v);
      }
      if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<User> get filteredUsers {
    return users.where((u) {
      final matchesRole = roleFilter == 'ALL' || u.role == roleFilter;
      final matchesStatus = statusFilter == 'ALL' || u.status == statusFilter;
      final matchesSearch = searchQuery.isEmpty ||
          u.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          u.email.toLowerCase().contains(searchQuery.toLowerCase());
      return matchesRole && matchesStatus && matchesSearch && u.status != 'SUSPENDED' && u.status != 'RESIGNED';
    }).toList();
  }

  List<User> get suspendedOrResignedDrivers {
    return users.where((u) => u.role == 'DRIVER' && (u.status == 'SUSPENDED' || u.status == 'RESIGNED')).toList();
  }

  void _showAddUserModal() {
    showDialog(
      context: context,
      builder: (context) => AddEditUserDialog(
        onSubmit: (user) {
          // After creating a user on the server, refresh the users list from the backend
          _fetchUsers();
        },
      ),
    );
  }

  void _showEditUserModal(User user) {
    showDialog(
      context: context,
      builder: (context) => AddEditUserDialog(
        user: user,
        onSubmit: (updatedUser) {
          setState(() {
            final idx = users.indexWhere((u) => u.id == updatedUser.id);
            if (idx != -1) users[idx] = updatedUser;
          });
        },
      ),
    );
  }

Future<void> _suspendUser(User user) async {
  final prevStatus = user.status;
  final prevDate = user.suspensionDate;
  final prevReason = user.suspensionReason;
  final prevActionedBy = user.actionedBy;

  setState(() {
    user.status = 'SUSPENDED';
    user.suspensionDate = DateTime.now();
    user.suspensionReason = 'Suspended by admin';
    user.actionedBy = 'Current Admin';
  });

  try {
    final api = APIService();
    final numericId = int.tryParse(user.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    int? resolvedId = numericId > 0 ? numericId : null;
    Map<String, dynamic>? serverUser;

    // If we don't have a numeric id, try to resolve by email
    if (resolvedId == null) {
      try {
        final emailEnc = Uri.encodeComponent(user.email);
        final got = await api.get('users/readByEmail/$emailEnc');
        if (got is Map<String, dynamic>) {
          serverUser = got;
          final idVal = got['user_id'] ?? got['userId'] ?? got['id'];
          if (idVal != null) resolvedId = int.tryParse(idVal.toString());
        }
      } catch (e) {
        AppLogger.debug('Could not resolve user by email', data: e.toString());
      }
    }

    // If we have a resolvedId, try to fetch canonical user to get first/last names
    if (resolvedId != null) {
      try {
        final got = await api.get('users/read/$resolvedId');
        if (got is Map<String, dynamic>) serverUser = got;
      } catch (_) {}
    }

    if (resolvedId == null) throw Exception('Unable to determine numeric user ID for update');

    final nameParts = user.name.trim().split(RegExp(r'\s+'));
    final firstName = serverUser != null
        ? (serverUser['first_name'] ?? serverUser['firstName'] ?? (nameParts.isNotEmpty ? nameParts.first : ''))
        : (nameParts.isNotEmpty ? nameParts.first : '');
    final lastName = serverUser != null
        ? (serverUser['last_name'] ?? serverUser['lastName'] ?? (nameParts.length > 1 ? nameParts.sublist(1).join(' ') : ''))
        : (nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');
    final emailToSend = serverUser != null ? (serverUser['email'] ?? user.email) : user.email;

    final payload = {
      'firstName': firstName,
      'lastName': lastName,
      'email': emailToSend,
      // extras (backend will ignore unknown keys if not handled)
      'is_suspended': true,
      'suspension_date': DateTime.now().toIso8601String(),
      'suspension_reason': 'Suspended by admin',
    };

    final result = await api.put('users/$resolvedId', payload);
    AppLogger.debug('Suspend API result', data: result);

    await _fetchUsers();

    try {
      final single = await api.get('users/read/$resolvedId');
      if (mounted) {
        final pretty = const JsonEncoder.withIndent('  ').convert(single);
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Server user record'),
            content: SizedBox(width: 600, child: SingleChildScrollView(child: Text(pretty))),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
          ),
        );
      }
    } catch (_) {}

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User suspended')));
    if (mounted) Navigator.pushReplacementNamed(context, '/admin/dashboard');
  } catch (e) {
    // revert optimistic update
    setState(() {
      user.status = prevStatus;
      user.suspensionDate = prevDate;
      user.suspensionReason = prevReason;
      user.actionedBy = prevActionedBy;
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to suspend user: $e')));
  }
}

Future<void> _reactivateUser(User user) async {
  final prevStatus = user.status;
  final prevDate = user.suspensionDate;
  final prevReason = user.suspensionReason;
  final prevActionedBy = user.actionedBy;

  setState(() {
    user.status = 'ACTIVE';
    user.suspensionDate = null;
    user.suspensionReason = null;
    user.actionedBy = null;
  });

  try {
    final api = APIService();
    final numericId = int.tryParse(user.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    int? resolvedId = numericId > 0 ? numericId : null;
    Map<String, dynamic>? serverUser;

    if (resolvedId == null) {
      try {
        final emailEnc = Uri.encodeComponent(user.email);
        final got = await api.get('users/readByEmail/$emailEnc');
        if (got is Map<String, dynamic>) {
          serverUser = got;
          final idVal = got['user_id'] ?? got['userId'] ?? got['id'];
          if (idVal != null) resolvedId = int.tryParse(idVal.toString());
        }
      } catch (e) {
        AppLogger.debug('Could not resolve user by email', data: e.toString());
      }
    }

    if (resolvedId != null) {
      try {
        final got = await api.get('users/read/$resolvedId');
        if (got is Map<String, dynamic>) serverUser = got;
      } catch (_) {}
    }

    if (resolvedId == null) throw Exception('Unable to determine numeric user ID for update');

    final nameParts = user.name.trim().split(RegExp(r'\s+'));
    final firstName = serverUser != null
        ? (serverUser['first_name'] ?? serverUser['firstName'] ?? (nameParts.isNotEmpty ? nameParts.first : ''))
        : (nameParts.isNotEmpty ? nameParts.first : '');
    final lastName = serverUser != null
        ? (serverUser['last_name'] ?? serverUser['lastName'] ?? (nameParts.length > 1 ? nameParts.sublist(1).join(' ') : ''))
        : (nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');
    final emailToSend = serverUser != null ? (serverUser['email'] ?? user.email) : user.email;

    final payload = {
      'firstName': firstName,
      'lastName': lastName,
      'email': emailToSend,
      // extras
      'is_suspended': false,
      'suspension_date': null,
      'suspension_reason': null,
    };

    final result = await api.put('users/$resolvedId', payload);
    AppLogger.debug('Reactivate API result', data: result);

    await _fetchUsers();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User reactivated')));

    try {
      final single = await api.get('users/read/$resolvedId');
      if (mounted) {
        final pretty = const JsonEncoder.withIndent('  ').convert(single);
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Server user record'),
            content: SizedBox(width: 600, child: SingleChildScrollView(child: Text(pretty))),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
          ),
        );
      }
    } catch (_) {}

    if (mounted) Navigator.pushReplacementNamed(context, '/admin/dashboard');
  } catch (e) {
    setState(() {
      user.status = prevStatus;
      user.suspensionDate = prevDate;
      user.suspensionReason = prevReason;
      user.actionedBy = prevActionedBy;
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reactivate user: $e')));
  }
}




  void _showUserDetails(User user) {
    showDialog(
      context: context,
      builder: (context) => UserDetailsDialog(user: user),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        DropdownButton<String>(
          value: roleFilter,
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('All Roles')),
            DropdownMenuItem(value: 'STUDENT', child: Text('Student')),
            DropdownMenuItem(value: 'DRIVER', child: Text('Driver')),
            DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
          ],
          onChanged: (val) => setState(() => roleFilter = val ?? 'ALL'),
        ),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: statusFilter,
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('All Status')),
            DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
            DropdownMenuItem(value: 'SUSPENDED', child: Text('Suspended')),
            DropdownMenuItem(value: 'RESIGNED', child: Text('Resigned')),
          ],
          onChanged: (val) => setState(() => statusFilter = val ?? 'ALL'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by name or email'),
            onChanged: (val) => setState(() => searchQuery = val),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.person_add),
          label: const Text('Add User'),
          onPressed: _showAddUserModal,
        ),
      ],
    );
  }

  Widget _buildUserTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('User ID')),
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Disability')),
          DataColumn(label: Text('Actions')),
        ],
        rows: filteredUsers.map((user) {
          return DataRow(cells: [
            DataCell(Text(user.id)),
            DataCell(Text(user.name)),
            DataCell(Text(user.email)),
            DataCell(Text(user.role)),
            DataCell(Text(user.status)),
            DataCell(Text(user.role == 'STUDENT' ? (user.isDisabled ? 'Yes' : 'No') : '-')),
            DataCell(Row(
              children: [
                IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit', onPressed: () => _showEditUserModal(user)),
                IconButton(icon: const Icon(Icons.block), tooltip: 'Suspend', onPressed: user.status == 'ACTIVE' ? () => _suspendUser(user) : null),
                IconButton(icon: const Icon(Icons.info), tooltip: 'View Details', onPressed: () => _showUserDetails(user)),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildSuspendedDriversTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('License')),
          DataColumn(label: Text('Suspension Date')),
          DataColumn(label: Text('Reason')),
          DataColumn(label: Text('Admin Actioned By')),
          DataColumn(label: Text('Actions')),
        ],
        rows: suspendedOrResignedDrivers.map((user) {
          return DataRow(cells: [
            DataCell(Text(user.name)),
            DataCell(Text(user.license ?? '-')),
            DataCell(Text(user.suspensionDate != null ? user.suspensionDate!.toLocal().toString().split(' ')[0] : '-')),
            DataCell(Text(user.suspensionReason ?? '-')),
            DataCell(Text(user.actionedBy ?? '-')),
            DataCell(Row(
              children: [
                if (user.status == 'SUSPENDED')
                  ElevatedButton(
                    child: const Text('Reactivate'),
                    onPressed: () => _reactivateUser(user),
                  ),
                IconButton(icon: const Icon(Icons.info), tooltip: 'View Details', onPressed: () => _showUserDetails(user)),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _loadingUsers = true;
      _loadingError = null;
    });
    try {
      final api = APIService();
      final res = await api.get('users/getAll');
      if (res is List) {
        // store raw JSON for debugging
        try {
          _lastUsersRawJson = const JsonEncoder.withIndent('  ').convert(res);
        } catch (_) {
          _lastUsersRawJson = res.toString();
        }
        final fetched = res.map((u) {
          final m = u as Map<String, dynamic>;
          final id = (m['user_id'] ?? m['userId'] ?? m['id'])?.toString() ?? 'U${DateTime.now().millisecondsSinceEpoch}';
          final first = (m['first_name'] ?? m['firstName'] ?? m['name'] ?? '').toString();
          final last = (m['last_name'] ?? m['lastName'] ?? m['surname'] ?? '').toString();
          final email = (m['email'] ?? '').toString();
          final roleStr = (m['role_name'] ?? m['role'] ?? '').toString().toUpperCase();
          final displayName = ('$first $last').trim();
          // Parse status and suspension-related fields from backend where available
          final statusStr = (m['status'] ?? m['user_status'] ?? m['account_status'])?.toString().toUpperCase() ?? 'ACTIVE';
          final boolFlag = (m['is_suspended'] ?? m['suspended'] ?? m['isSuspended']) ?? false;
          final isSuspBool = (boolFlag is bool && boolFlag) || (boolFlag is String && boolFlag.toString().toLowerCase() == 'true');
          final isResigned = (m['resigned'] == true) || (m['is_resigned'] == true) || (statusStr == 'RESIGNED');
          final computedStatus = (statusStr == 'SUSPENDED' || isSuspBool || isResigned) ? (isResigned ? 'RESIGNED' : 'SUSPENDED') : statusStr;

          final suspensionDate = _parseDate(m['suspension_date'] ?? m['suspended_at'] ?? m['resigned_at'] ?? m['updatedAt'] ?? m['updated_at']);
          final suspensionReason = (m['suspension_reason'] ?? m['suspensionReason'] ?? m['reason'])?.toString();
          final actionedBy = (m['actionedBy'] ?? m['actioned_by'] ?? m['modifiedBy'])?.toString();
          final license = (m['driver_license'] ?? m['license'] ?? m['driverLicense'])?.toString();
          final phone = (m['phoneNumber'] ?? m['phone'] ?? m['contact'])?.toString();
          final isDisabled = (m['disability'] ?? m['is_disabled'] ?? m['disabled']) ?? false;

          return User(
            id: id,
            name: displayName.isNotEmpty ? displayName : email,
            email: email,
            role: roleStr.isNotEmpty ? roleStr : 'STUDENT',
            status: computedStatus,
            isDisabled: isDisabled is bool ? isDisabled : (isDisabled.toString().toLowerCase() == 'true'),
            phone: phone,
            license: license,
            suspensionDate: suspensionDate,
            suspensionReason: suspensionReason,
            actionedBy: actionedBy,
          );
        }).toList();

        setState(() {
          users.clear();
          users.addAll(fetched);
          _loadingUsers = false;
        });
        // show success briefly (optional)
      } else {
        // Try to handle wrapped responses like { data: [...] } or { users: [...] }
        if (res is Map<String, dynamic>) {
          List<dynamic>? maybeList;
          if (res['data'] is List) maybeList = res['data'] as List<dynamic>;
          else if (res['users'] is List) maybeList = res['users'] as List<dynamic>;
          if (maybeList != null) {
            // Re-run mapping by recursively calling API result handling
            try {
              final jsonStr = const JsonEncoder.withIndent('  ').convert(maybeList);
              _lastUsersRawJson = jsonStr;
            } catch (_) {
              _lastUsersRawJson = maybeList.toString();
            }
            final fetched = maybeList.map((u) {
              final m = u as Map<String, dynamic>;
              final id = (m['user_id'] ?? m['userId'] ?? m['id'])?.toString() ?? 'U${DateTime.now().millisecondsSinceEpoch}';
              final first = (m['first_name'] ?? m['firstName'] ?? m['name'] ?? '').toString();
              final last = (m['last_name'] ?? m['lastName'] ?? m['surname'] ?? '').toString();
              final email = (m['email'] ?? '').toString();
              final roleStr = (m['role_name'] ?? m['role'] ?? '').toString().toUpperCase();
              final displayName = ('$first $last').trim();
              final statusStr = (m['status'] ?? m['user_status'] ?? m['account_status'])?.toString().toUpperCase() ?? 'ACTIVE';
              final boolFlag = (m['is_suspended'] ?? m['suspended'] ?? m['isSuspended']) ?? false;
              final isSuspBool = (boolFlag is bool && boolFlag) || (boolFlag is String && boolFlag.toString().toLowerCase() == 'true');
              final isResigned = (m['resigned'] == true) || (m['is_resigned'] == true) || (statusStr == 'RESIGNED');
              final computedStatus = (statusStr == 'SUSPENDED' || isSuspBool || isResigned) ? (isResigned ? 'RESIGNED' : 'SUSPENDED') : statusStr;
              final suspensionDate = _parseDate(m['suspension_date'] ?? m['suspended_at'] ?? m['resigned_at'] ?? m['updatedAt'] ?? m['updated_at']);
              final suspensionReason = (m['suspension_reason'] ?? m['suspensionReason'] ?? m['reason'])?.toString();
              final actionedBy = (m['actionedBy'] ?? m['actioned_by'] ?? m['modifiedBy'])?.toString();
              final license = (m['driver_license'] ?? m['license'] ?? m['driverLicense'])?.toString();
              final phone = (m['phoneNumber'] ?? m['phone'] ?? m['contact'])?.toString();
              final isDisabled = (m['disability'] ?? m['is_disabled'] ?? m['disabled']) ?? false;

              return User(
                id: id,
                name: displayName.isNotEmpty ? displayName : email,
                email: email,
                role: roleStr.isNotEmpty ? roleStr : 'STUDENT',
                status: computedStatus,
                isDisabled: isDisabled is bool ? isDisabled : (isDisabled.toString().toLowerCase() == 'true'),
                phone: phone,
                license: license,
                suspensionDate: suspensionDate,
                suspensionReason: suspensionReason,
                actionedBy: actionedBy,
              );
            }).toList();

            setState(() {
              users.clear();
              users.addAll(fetched);
              _loadingUsers = false;
            });
            return;
          }
        }

        setState(() {
          _loadingError = 'Unexpected response from server';
          _loadingUsers = false;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load users: Unexpected response')));
      }
    } catch (e) {
      setState(() {
        _loadingError = e.toString();
        _loadingUsers = false;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load users: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh users',
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchUsers(),
          ),
          IconButton(
            tooltip: 'View raw users JSON',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              if (_lastUsersRawJson == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No raw users JSON available')));
                return;
              }
              showDialog(context: context, builder: (_) => AlertDialog(
                title: const Text('Raw users JSON'),
                content: SizedBox(width: 600, child: SingleChildScrollView(child: Text(_lastUsersRawJson!))),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
              ));
            },
          ),
        ],
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'All Users'),
                Tab(text: 'Resigned/Suspended Drivers'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Column(
                    children: [
                      _buildFilters(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _loadingUsers
                            ? const Center(child: CircularProgressIndicator())
                            : (_loadingError != null
                                ? Center(child: Text('Failed to load users: $_loadingError'))
                                : _buildUserTable()),
                      ),
                    ],
                  ),
                  _buildSuspendedDriversTable(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Add/Edit User Dialog
class AddEditUserDialog extends StatefulWidget {
  final User? user;
  final void Function(User user) onSubmit;
  const AddEditUserDialog({Key? key, this.user, required this.onSubmit}) : super(key: key);

  @override
  State<AddEditUserDialog> createState() => _AddEditUserDialogState();
}

class _AddEditUserDialogState extends State<AddEditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late String name;
  late String email;
  String role = 'STUDENT';
  String status = 'ACTIVE';
  bool isDisabled = false;
  String? phone;
  String? license;
  String? shuttle;
  String? staffId;
  String? disabilityType;
  bool requiresMinibus = false;
  String? password;
  bool _isSubmitting = false;
  final RegExp _emailRegex = RegExp(r"^[\w\.-]+@[\w\.-]+\.[a-zA-Z]{2,}$");

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    name = u?.name ?? '';
    email = u?.email ?? '';
    role = u?.role ?? 'STUDENT';
    status = u?.status ?? 'ACTIVE';
    isDisabled = u?.isDisabled ?? false;
    phone = u?.phone;
    license = u?.license;
    shuttle = u?.shuttle;
    // staffId and disability fields default to null/false; if editing a user add mapping here if you store them
    staffId = null;
    disabilityType = null;
    requiresMinibus = false;
  }

  Map<String, String> _splitFullName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return {'name': '', 'surname': ''};
    if (parts.length == 1) return {'name': parts.first, 'surname': ''};
    return {'name': parts.first, 'surname': parts.sublist(1).join(' ')};
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = role == 'DRIVER';
    return AlertDialog(
      title: Text(widget.user == null ? 'Add User' : 'Edit User'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter name' : null,
                onSaved: (v) => name = v?.trim() ?? '',
              ),
              TextFormField(
                initialValue: email,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter email';
                  if (!_emailRegex.hasMatch(v.trim())) return 'Enter a valid email address';
                  return null;
                },
                onSaved: (v) => email = v?.trim().toLowerCase() ?? '',
              ),
              DropdownButtonFormField<String>(
                initialValue: role,
                items: const [
                  DropdownMenuItem(value: 'STUDENT', child: Text('Student')),
                  DropdownMenuItem(value: 'DRIVER', child: Text('Driver')),
                  DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                ],
                onChanged: (v) => setState(() => role = v ?? 'STUDENT'),
                decoration: const InputDecoration(labelText: 'Role'),
              ),
              DropdownButtonFormField<String>(
                initialValue: status,
                items: const [
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                  DropdownMenuItem(value: 'SUSPENDED', child: Text('Suspended')),
                  DropdownMenuItem(value: 'RESIGNED', child: Text('Resigned')),
                ],
                onChanged: (v) => setState(() => status = v ?? 'ACTIVE'),
                decoration: const InputDecoration(labelText: 'Status'),
              ),
              if (role == 'STUDENT')
                CheckboxListTile(
                  value: isDisabled,
                  onChanged: (v) => setState(() => isDisabled = v ?? false),
                  title: const Text('Disability'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              if (isDisabled) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: disabilityType,
                  items: const [
                    DropdownMenuItem(value: 'Hearing', child: Text('Hearing')),
                    DropdownMenuItem(value: 'Mobility', child: Text('Mobility')),
                    DropdownMenuItem(value: 'Cognitive', child: Text('Cognitive')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => disabilityType = v),
                  decoration: const InputDecoration(labelText: 'Disability Type'),
                  validator: (v) => isDisabled && (v == null || v.isEmpty) ? 'Select disability type' : null,
                ),
                SwitchListTile(
                  title: const Text('Requires Minibus'),
                  value: requiresMinibus,
                  onChanged: (v) => setState(() => requiresMinibus = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              if (isDriver || role == 'ADMIN') ...[
                TextFormField(
                  initialValue: phone,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  onSaved: (v) => phone = v,
                ),
                TextFormField(
                  initialValue: license,
                  decoration: const InputDecoration(labelText: 'Driver License'),
                  onSaved: (v) => license = v,
                ),
                TextFormField(
                  initialValue: staffId,
                  decoration: const InputDecoration(labelText: 'Staff ID'),
                  validator: (v) {
                    if ((role == 'DRIVER' || role == 'ADMIN') && (v == null || v.trim().isEmpty)) return 'Enter Staff ID';
                    return null;
                  },
                  onSaved: (v) => staffId = v?.trim(),
                ),
                TextFormField(
                  initialValue: shuttle,
                  decoration: const InputDecoration(labelText: 'Shuttle Assignment (optional)'),
                  onSaved: (v) => shuttle = v,
                ),
              ],
              if (widget.user == null) // Only for add
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  onSaved: (v) => password = v ?? '',
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter password';
                    if (v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
        ElevatedButton(
          child: _isSubmitting ? SizedBox(height:16,width:16, child: CircularProgressIndicator(color: Colors.white, strokeWidth:2)) : const Text('Submit'),
          onPressed: _isSubmitting ? null : () async {
            if (!_formKey.currentState!.validate()) return;
            _formKey.currentState!.save();

            // If adding a new user, call API and only add to local list after success
            if (widget.user == null) {
              setState(() => _isSubmitting = true);
              final nameParts = _splitFullName(name);
              final payload = <String, dynamic>{
                'name': (nameParts['name'] ?? '').trim(),
                'surname': (nameParts['surname'] ?? '').trim(),
                'email': email.trim().toLowerCase(),
                'password': password ?? '',
                'phoneNumber': phone,
                'disability': isDisabled,
                'role': role,
                // Add driver-specific fields if provided
                if (license != null && license!.isNotEmpty) 'driverLicense': license,
                // Include staff id for staff roles (both snake_case and camelCase accepted by backend)
                if ((role == 'DRIVER' || role == 'ADMIN') && staffId != null && staffId!.isNotEmpty) 'staffId': staffId,
                if ((role == 'DRIVER' || role == 'ADMIN') && staffId != null && staffId!.isNotEmpty) 'staff_id': staffId,
                // Student disability fields
                if (isDisabled && disabilityType != null && disabilityType!.isNotEmpty) 'disabilityType': disabilityType,
                if (isDisabled && disabilityType != null && disabilityType!.isNotEmpty) 'disability_type': disabilityType,
                if (isDisabled) 'requiresMinibus': requiresMinibus,
                if (isDisabled) 'requires_minibus': requiresMinibus,
              };

              try {
                final result = await APIService().registerUser(payload);
                // result may be null or a map representing the created user
                String newId = 'U${DateTime.now().millisecondsSinceEpoch}';
                if (result is Map) {
                  // Backend commonly returns { message: ..., user: { ... } }
                  final dynamic userObj = result['user'] ?? result;
                  if (userObj is Map) {
                    if (userObj['user_id'] != null) {
                      newId = userObj['user_id'].toString();
                    } else if (userObj['userId'] != null) {
                      newId = userObj['userId'].toString();
                    } else if (userObj['id'] != null) {
                      newId = userObj['id'].toString();
                    }
                  } else {
                    if (result['userId'] != null) newId = result['userId'].toString();
                    else if (result['user_id'] != null) newId = result['user_id'].toString();
                    else if (result['id'] != null) newId = result['id'].toString();
                  }
                }

                final newUser = User(
                  id: newId,
                  name: name,
                  email: email,
                  role: role,
                  status: status,
                  isDisabled: isDisabled,
                  phone: phone,
                  license: license,
                  shuttle: shuttle,
                );

                if (mounted) widget.onSubmit(newUser);
                if (mounted) Navigator.pop(context);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User created successfully')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create user: $e')));
              } finally {
                if (mounted) setState(() => _isSubmitting = false);
              }
            } else {
              // Editing local user - update locally and optionally call update API in background
              final updated = User(
                id: widget.user!.id,
                name: name,
                email: email,
                role: role,
                status: status,
                isDisabled: isDisabled,
                phone: phone,
                license: license,
                shuttle: shuttle,
              );

              // Immediately update UI
              widget.onSubmit(updated);
              Navigator.pop(context);

              // Optionally, attempt server update; ignore errors here but you can surface them
              try {
                final nameParts = _splitFullName(name);
                // Best-effort: update server using the backend's PUT /users/<id> route.
                try {
                  final api = APIService();
                  final namePartsInner = nameParts;
                  int? resolvedId = int.tryParse(updated.id.replaceAll(RegExp(r'[^0-9]'), ''));
                  Map<String, dynamic>? serverUser;

                  // If no numeric id, try to resolve by email
                  if (resolvedId == null || resolvedId == 0) {
                    try {
                      final got = await api.get('users/readByEmail/${Uri.encodeComponent(updated.email)}');
                      if (got is Map<String, dynamic>) {
                        serverUser = got;
                        final idVal = got['user_id'] ?? got['userId'] ?? got['id'];
                        if (idVal != null) resolvedId = int.tryParse(idVal.toString());
                      }
                    } catch (_) {}
                  } else {
                    try {
                      final got = await api.get('users/read/$resolvedId');
                      if (got is Map<String, dynamic>) serverUser = got;
                    } catch (_) {}
                  }

                  if (resolvedId != null && resolvedId > 0) {
                    final firstName = (serverUser != null
                        ? (serverUser['first_name'] ?? serverUser['firstName'] ?? (namePartsInner['name'] ?? ''))
                        : (namePartsInner['name'] ?? ''))
                        .toString();
                    final lastName = (serverUser != null
                        ? (serverUser['last_name'] ?? serverUser['lastName'] ?? (namePartsInner['surname'] ?? ''))
                        : (namePartsInner['surname'] ?? ''))
                        .toString();
                    final emailToSend = serverUser != null ? (serverUser['email'] ?? updated.email).toString() : updated.email;

                    final payload = <String, dynamic>{
                      'firstName': firstName,
                      'lastName': lastName,
                      'email': emailToSend,
                    };
                    if (phone != null) payload['phoneNumber'] = phone;
                    if (staffId != null && staffId!.isNotEmpty) {
                      payload['staffId'] = staffId;
                      payload['staff_id'] = staffId;
                    }
                    // Send update to canonical backend path
                    await api.put('users/$resolvedId', payload);
                  }
                } catch (_) {}
               } catch (_) {}
            }
          },
        ),
      ],
    );
  }
}

// User Details Dialog (for drivers)
class UserDetailsDialog extends StatelessWidget {
  final User user;
  const UserDetailsDialog({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('User Details'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${user.name}'),
            Text('Email: ${user.email}'),
            Text('Role: ${user.role}'),
            Text('Status: ${user.status}'),
            if (user.role == 'DRIVER') ...[
              Text('Phone: ${user.phone ?? '-'}'),
              Text('License: ${user.license ?? '-'}'),
              Text('Shuttle: ${user.shuttle ?? '-'}'),
              if (user.suspensionDate != null)
                Text('Suspension Date: ${user.suspensionDate!.toLocal().toString().split(' ')[0]}'),
              if (user.suspensionReason != null)
                Text('Suspension Reason: ${user.suspensionReason}'),
              if (user.actionedBy != null)
                Text('Actioned By: ${user.actionedBy}'),
              // Add more driver history/activity info here as needed
            ],
          ],
        ),
      ),
      actions: [
        TextButton(child: const Text('Close'), onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}

