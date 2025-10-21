import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/shuttle_model.dart';
import '../../services/shuttle_service.dart';
import 'manage_schedule.dart';

class ManageShuttlesScreen extends StatefulWidget {
  const ManageShuttlesScreen({super.key});

  @override
  State<ManageShuttlesScreen> createState() => _ManageShuttlesScreenState();
}

class _ManageShuttlesScreenState extends State<ManageShuttlesScreen> {
  final ShuttleService _service = ShuttleService();
  List<Shuttle> shuttles = [];
  List<Map<String, dynamic>> statuses = [];
  List<Map<String, dynamic>> types = [];
  List<Map<String, dynamic>> drivers = [];
  List<Map<String, dynamic>> driverOptions = []; // driver_id + name
  List<Map<String, dynamic>> schedules = [];
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> routes = []; // <-- added to hold routes
  Map<int, String> shuttleAssignedDriver = {}; // shuttleId -> driver name
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.getShuttles(),
        _service.fetchStatuses(),
        _service.fetchTypes(),
        _service.getDrivers(),
        _service.getSchedules(),
        _service.fetchUsers(),
        _service.getDriverAssignments(),
        _service.getRoutes(), // fetch routes
      ]);

      final fetchedShuttles = results[0] as List<Shuttle>;
      final fetchedStatuses = results[1] as List<Map<String, dynamic>>;
      final fetchedTypes = results[2] as List<Map<String, dynamic>>;
      final fetchedDrivers = results[3] as List<Map<String, dynamic>>;
      final fetchedSchedules = results[4] as List<Map<String, dynamic>>;
      final fetchedUsers = results[5] as List<Map<String, dynamic>>;
      final fetchedAssignments = results[6] as List<Map<String, dynamic>>;
      final fetchedRoutes = results[7] as List<Map<String, dynamic>>; // routes

      // Build driver options by resolving user name for driver.user_id
      final options = <Map<String, dynamic>>[];
      // helper to pick first existing key
      dynamic pick(Map m, List keys) {
        for (final k in keys) if (m.containsKey(k) && m[k] != null) return m[k];
        return null;
      }
      int? toInt(dynamic v) {
        if (v == null) return null;
        if (v is int) return v;
        if (v is double) return v.toInt();
        if (v is String) return int.tryParse(v);
        return null;
      }
      String keyOf(dynamic v) => v == null ? '' : v.toString();

      // normalize users into a map by stringified id keys for quick lookup
      final Map<String, Map<String, dynamic>> usersById = {};
      for (final u in fetchedUsers) {
        final uid = pick(u, ['user_id', 'userId', 'id']);
        final k = keyOf(uid);
        if (k.isNotEmpty) usersById[k] = u;
      }

      for (final d in fetchedDrivers) {
        final driverIdRaw = pick(d, ['driver_id', 'driverId', 'id']);
        final uidRaw = pick(d, ['user_id', 'userId', 'id']);
        final user = usersById[keyOf(uidRaw)] ?? {};
        String name = '';
        if (user.isNotEmpty) {
          final fn = pick(user, ['first_name', 'firstName', 'first']) ?? '';
          final ln = pick(user, ['last_name', 'lastName', 'last']) ?? '';
          name = ('$fn $ln').trim();
        }
        // Include drivers even if their id is a string/UUID; we'll compare by string when matching
        if (driverIdRaw != null) {
          options.add({'driver_id': driverIdRaw, 'user_id': uidRaw, 'name': name, 'license_number': pick(d, ['license_number', 'licenseNumber'])});
        }
      }

      // If backend didn't return drivers, try to derive drivers from users (role-based fallback)
      if (options.isEmpty) {
        debugPrint('[ManageShuttles] No drivers returned from drivers endpoint, attempting fallback from users');
        bool userLooksLikeDriver(Map u) {
          final r = pick(u, ['role', 'role_name', 'roleName']);
          if (r != null && r.toString().toLowerCase().contains('driver')) return true;
          final rolesVal = u['roles'] ?? u['roleIds'] ?? u['role_ids'] ?? u['role'];
          if (rolesVal is List) {
            for (final rv in rolesVal) {
              if (rv != null && rv.toString().toLowerCase().contains('driver')) return true;
            }
          }
          if (u.containsKey('is_driver')) {
            final v = u['is_driver'];
            if (v == true || v == 1 || v == '1' || v == 'true') return true;
          }
          return false;
        }

        int added = 0;
        for (final u in fetchedUsers) {
          if (!userLooksLikeDriver(u)) continue;
          final uid = pick(u, ['user_id', 'userId', 'id']);
          final driverId = uid ?? ('user_${keyOf(uid)}');
          final fn = pick(u, ['first_name', 'firstName', 'first']) ?? '';
          final ln = pick(u, ['last_name', 'lastName', 'last']) ?? '';
          final name = ('$fn $ln').trim();
          options.add({'driver_id': driverId, 'user_id': uid, 'name': name.isNotEmpty ? name : 'User ${keyOf(uid)}', 'license_number': null});
          added++;
        }
        debugPrint('[ManageShuttles] Fallback added $added drivers from users');
      }

      // If still empty, as a last resort include all users as potential drivers (so admin can assign)
      if (options.isEmpty && fetchedUsers.isNotEmpty) {
        debugPrint('[ManageShuttles] No drivers found via heuristics; adding all users as potential drivers (last-resort)');
        for (final u in fetchedUsers) {
          final uid = pick(u, ['user_id', 'userId', 'id']);
          final fn = pick(u, ['first_name', 'firstName', 'first']) ?? '';
          final ln = pick(u, ['last_name', 'lastName', 'last']) ?? '';
          final name = ('$fn $ln').trim();
          options.add({'driver_id': uid ?? ('user_${keyOf(uid)}'), 'user_id': uid, 'name': name.isNotEmpty ? name : 'User ${keyOf(uid)}', 'license_number': null});
        }
        debugPrint('[ManageShuttles] Last-resort fallback added ${options.length} users as drivers');
      }

      // Populate shuttleAssignedDriver from fetched assignments
      final Map<int, String> assignmentMap = {};
      for (final a in fetchedAssignments) {
        final shuttleIdRaw = a['shuttle_id'] ?? a['shuttleId'] ?? a['id'];
        final driverIdRaw = a['driver_id'] ?? a['driverId'];
        final shuttleId = toInt(shuttleIdRaw);
        if (shuttleId == null || driverIdRaw == null) continue;
        final driverRow = options.firstWhere((d) => d['driver_id']?.toString() == driverIdRaw.toString(), orElse: () => {});
        final driverName = (driverRow.isNotEmpty ? (driverRow['name'] as String?) : null) ?? 'Driver ${driverIdRaw.toString()}';
        assignmentMap[shuttleId] = driverName;
      }

      // Normalize schedules into uniform maps with schedule_id
      final normalizedSchedules = <Map<String, dynamic>>[];
      for (final s in fetchedSchedules) {
        final sidRaw = pick(s, ['schedule_id', 'scheduleId', 'id']);
        if (sidRaw == null) continue; // skip schedules without any id
        final map = Map<String, dynamic>.from(s);
        map['schedule_id'] = sidRaw; // keep raw id type (int or String)
        normalizedSchedules.add(map);
      }

      // Normalize routes into uniform maps with route_id and name
      final normalizedRoutes = <Map<String, dynamic>>[];
      for (final r in fetchedRoutes) {
        final ridRaw = pick(r, ['route_id', 'routeId', 'id']);
        if (ridRaw == null) continue;
        final map = Map<String, dynamic>.from(r);
        map['route_id'] = ridRaw;
        final rname = pick(r, ['name', 'route_name', 'routeName']) ?? 'Route ${ridRaw.toString()}';
        map['name'] = rname;
        normalizedRoutes.add(map);
      }

      // replace schedules with normalizedSchedules for UI consumption
      final fetchedSchedulesNormalized = normalizedSchedules;

      // Prefer deduplication by normalized name so dropdown values are unique
      final Map<String, Map<String, dynamic>> seenStatusByName = {};
      final List<Map<String, dynamic>> fallbackStatuses = [];
      for (final s in fetchedStatuses) {
        final name = (s['status_name'] ?? s['statusName'] ?? '').toString().trim().toLowerCase();
        if (name.isNotEmpty) {
          if (!seenStatusByName.containsKey(name)) seenStatusByName[name] = s;
        } else {
          fallbackStatuses.add(s);
        }
      }
      // If there are fallback entries with no name, dedupe by id among them
      final Map<dynamic, Map<String, dynamic>> seenFallbackStatusById = {};
      for (final s in fallbackStatuses) {
        final id = s['status_id'] ?? s['statusId'];
        if (id != null && !seenFallbackStatusById.containsKey(id)) seenFallbackStatusById[id] = s;
      }
      final uniqueStatuses = [...seenStatusByName.values, ...seenFallbackStatusById.values];

      // Types: dedupe by normalized type_name first, then fallback to id
      final Map<String, Map<String, dynamic>> seenTypeByName = {};
      final List<Map<String, dynamic>> fallbackTypes = [];
      for (final t in fetchedTypes) {
        final name = (t['type_name'] ?? t['typeName'] ?? '').toString().trim().toLowerCase();
        if (name.isNotEmpty) {
          if (!seenTypeByName.containsKey(name)) seenTypeByName[name] = t;
        } else {
          fallbackTypes.add(t);
        }
      }
      final Map<dynamic, Map<String, dynamic>> seenFallbackTypeById = {};
      for (final t in fallbackTypes) {
        final id = t['type_id'] ?? t['typeId'];
        if (id != null && !seenFallbackTypeById.containsKey(id)) seenFallbackTypeById[id] = t;
      }
      final uniqueTypes = [...seenTypeByName.values, ...seenFallbackTypeById.values];

      // Final dedupe: ensure uniqueness by id (keep first occurrence)
      final Map<dynamic, Map<String, dynamic>> uniqStatusById = {};
      for (final s in uniqueStatuses) {
        final id = s['status_id'] ?? s['statusId'];
        if (id != null && !uniqStatusById.containsKey(id)) uniqStatusById[id] = s;
      }
      final finalStatuses = uniqStatusById.values.toList();

      final Map<dynamic, Map<String, dynamic>> uniqTypeById = {};
      for (final t in uniqueTypes) {
        final id = t['type_id'] ?? t['typeId'];
        if (id != null && !uniqTypeById.containsKey(id)) uniqTypeById[id] = t;
      }
      final finalTypes = uniqTypeById.values.toList();

      setState(() {
        shuttles = fetchedShuttles;
        statuses = finalStatuses;
        types = finalTypes;
        drivers = fetchedDrivers;
        driverOptions = options;
        schedules = fetchedSchedulesNormalized;
        users = fetchedUsers;
        routes = normalizedRoutes; // set routes
        shuttleAssignedDriver = assignmentMap;
      });
    } catch (e) {
      _showDeferredSnackBar('Failed to load shuttles: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return Colors.blue;
      case 'in service':
      case 'in_service':
        return Colors.green;
      case 'under maintenance':
      case 'under_maintenance':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _markMaintenance(int index) async {
    final shuttle = shuttles[index];
    try {
      final statusRow = statuses.firstWhere((s) => (s['status_name'] as String).toLowerCase().contains('maintenance'), orElse: () => {});
      final statusId = statusRow['status_id'] as int?;
      if (statusId == null) throw Exception('Maintenance status not found');
      final updated = await _service.updateShuttleStatus(shuttle.id!, statusId);
      setState(() => shuttles[index] = updated);
    } catch (e) {
      _showDeferredSnackBar('Failed to mark maintenance: $e');
    }
  }

  Future<void> _assignDriver(int index) async {
    // Keep existing local assign behaviour for now. Driver assignments should use driver assignment endpoints.
    _showAssignDriverDialog(index);
  }

  Future<void> _deleteShuttle(int index) async {
    final shuttle = shuttles[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shuttle'),
        content: Text('Are you sure you want to delete shuttle ${shuttle.licensePlate}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _service.deleteShuttle(shuttle.id!);
      setState(() => shuttles.removeAt(index));
      _showDeferredSnackBar('Shuttle deleted');
    } catch (e) {
      _showDeferredSnackBar('Failed to delete shuttle: $e');
    }
  }

  // Helper: show a snackbar after a short delay to avoid overlay updates during pointer/device events
  void _showDeferredSnackBar(String message, {Duration delay = const Duration(milliseconds: 50)}) {
    if (!mounted) return;
    Future.delayed(delay, () {
      if (!mounted) return;
      try {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      } catch (e) {
        debugPrint('Failed to show snackbar: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note),
            tooltip: 'Manage Schedules',
            onPressed: _showManageSchedulesDialog,
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug: show parsed drivers/schedules',
            onPressed: _showDebugDialog,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showShuttleDialog(),
        child: const Icon(Icons.add),
        tooltip: 'Add Shuttle',
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: shuttles.asMap().entries.map((entry) {
                  final index = entry.key;
                  final shuttle = entry.value;
                  final statusLabel = shuttle.statusName ?? shuttle.statusId.toString();
                  final typeLabel = shuttle.typeName ?? shuttle.typeId.toString();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                typeLabel.toLowerCase().contains('bus') ? Icons.directions_bus : Icons.airport_shuttle,
                                color: Colors.blue,
                                size: 32,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                shuttle.model,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const Spacer(),
                              Container(
                                width: 12,
                                height: 12,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: _statusColor(statusLabel),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              // Use numeric status_id values for the inline dropdown to avoid duplicate string-value issues
                              DropdownButton<int>(
                                value: (() {
                                  final ids = statuses.map((s) => (s['status_id'] ?? s['statusId']) as int?).whereType<int>().toSet();
                                  return ids.contains(shuttle.statusId) ? shuttle.statusId : null;
                                })(),
                                items: statuses.map((s) => DropdownMenuItem<int>(
                                      value: (s['status_id'] ?? s['statusId']) as int,
                                      child: Text((s['status_name'] ?? s['statusName'] ?? '').toString()),
                                    )).toList(),
                                onChanged: (value) async {
                                  if (value == null) return;
                                  try {
                                    final statusId = value;
                                    final updated = await _service.updateShuttleStatus(shuttle.id!, statusId);
                                    setState(() => shuttles[index] = updated);
                                  } catch (e) {
                                    _showDeferredSnackBar('Failed to update status: $e');
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text('Plate: ${shuttle.licensePlate}'),
                          Text('Capacity: ${shuttle.capacity}'),
                          Text('Type: $typeLabel'),
                          Text('Driver: ${shuttleAssignedDriver[shuttle.id] ?? 'Unassigned'}'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              ElevatedButton(onPressed: () => _showShuttleDialog(editIndex: index, shuttle: shuttle), child: const Text('Edit')),
                              const SizedBox(width: 8),
                              ElevatedButton(onPressed: () => _markMaintenance(index), child: const Text('Mark Maintenance')),
                              const SizedBox(width: 8),
                              ElevatedButton(onPressed: () => _assignDriver(index), child: const Text('Assign Driver')),
                              const SizedBox(width: 8),
                              ElevatedButton(onPressed: () => _deleteShuttle(index), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  Future<void> _showShuttleDialog({int? editIndex, Shuttle? shuttle}) async {
    final _formKey = GlobalKey<FormState>();
    final makeController = TextEditingController(text: shuttle?.make ?? '');
    final modelController = TextEditingController(text: shuttle?.model ?? '');
    final yearController = TextEditingController(text: shuttle?.year.toString() ?? '');
    final capacityController = TextEditingController(text: shuttle?.capacity.toString() ?? '');
    final plateController = TextEditingController(text: shuttle?.licensePlate ?? '');
    int selectedTypeId = shuttle?.typeId ?? (types.isNotEmpty ? types.first['type_id'] as int : 1);
    int selectedStatusId = shuttle?.statusId ?? (statuses.isNotEmpty ? statuses.first['status_id'] as int : 1);

    // Capture the outer context to use for SnackBars (dialog builder shadows context)
    final outerContext = context;

    final dialogResult = await showDialog<String?>(
      context: outerContext,
      builder: (context) => AlertDialog(
        title: Text(editIndex == null ? 'Add Shuttle' : 'Edit Shuttle'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: makeController, decoration: const InputDecoration(labelText: 'Make'), validator: (v) => v == null || v.isEmpty ? 'Enter make' : null),
                TextFormField(controller: modelController, decoration: const InputDecoration(labelText: 'Model'), validator: (v) => v == null || v.isEmpty ? 'Enter model' : null),
                TextFormField(controller: yearController, decoration: const InputDecoration(labelText: 'Year'), keyboardType: TextInputType.number, validator: (v) => v == null || v.isEmpty ? 'Enter year' : null),
                TextFormField(controller: capacityController, decoration: const InputDecoration(labelText: 'Capacity'), keyboardType: TextInputType.number, validator: (v) => v == null || v.isEmpty ? 'Enter capacity' : null),
                TextFormField(controller: plateController, decoration: const InputDecoration(labelText: 'License Plate'), validator: (v) => v == null || v.isEmpty ? 'Enter plate' : null),
                DropdownButtonFormField<int>(
                  initialValue: (() {
                    final ids = types.map((t) => t['type_id'] as int).toSet();
                    return ids.contains(selectedTypeId) ? selectedTypeId : null;
                  })(),
                  items: types.map((t) => DropdownMenuItem<int>(value: t['type_id'] as int, child: Text((t['type_name'] ?? '').toString()))).toList(),
                  onChanged: (v) => selectedTypeId = v ?? selectedTypeId,
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                DropdownButtonFormField<int>(
                  initialValue: (() {
                    final ids = statuses.map((s) => s['status_id'] as int).toSet();
                    return ids.contains(selectedStatusId) ? selectedStatusId : null;
                  })(),
                  items: statuses.map((s) => DropdownMenuItem<int>(value: s['status_id'] as int, child: Text((s['status_name'] ?? '').toString()))).toList(),
                  onChanged: (v) => selectedStatusId = v ?? selectedStatusId,
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              final newShuttle = Shuttle(
                id: shuttle?.id,
                make: makeController.text,
                model: modelController.text,
                year: int.tryParse(yearController.text) ?? 0,
                capacity: int.tryParse(capacityController.text) ?? 0,
                licensePlate: plateController.text,
                statusId: selectedStatusId,
                typeId: selectedTypeId,
              );

              try {
                if (editIndex == null) {
                  final created = await _service.createShuttle(newShuttle);
                  setState(() => shuttles.insert(0, created));
                  // return a marker so the outer caller can show the snackbar safely
                  Navigator.of(context).pop('shuttle_added');
                } else {
                  final updated = await _service.updateShuttle(newShuttle.id ?? shuttles[editIndex].id!, newShuttle);
                  setState(() => shuttles[editIndex] = updated);
                  Navigator.of(context).pop('shuttle_updated');
                }
              } catch (e) {
                // Return an error result; outer caller will show the snackbar
                Navigator.of(context).pop('shuttle_error:$e');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // After dialog completes, show snackbars from the outer context (avoids overlay changes during pointer/device updates)
    if (!mounted) return;
    if (dialogResult == 'shuttle_added') {
      _showDeferredSnackBar('Shuttle added');
    } else if (dialogResult == 'shuttle_updated') {
      _showDeferredSnackBar('Shuttle updated');
    } else if (dialogResult != null && dialogResult.startsWith('shuttle_error:')) {
      final msg = dialogResult.substring('shuttle_error:'.length);
      _showDeferredSnackBar('Failed to save shuttle: $msg');
    }
  }

  Future<void> _showAssignDriverDialog(int index) async {
    final shuttle = shuttles[index];
    if (shuttle.id == null) {
      // This is outside a dialog, safe to show immediately
      _showDeferredSnackBar('Cannot assign driver to unsaved shuttle');
      return;
    }

    // Debug: log context for troubleshooting
    debugPrint('Opening Assign Driver dialog for shuttle id=${shuttle.id} index=$index');
    debugPrint('driverOptions count=${driverOptions.length}, schedules count=${schedules.length}');
    debugPrint('driverOptions=${driverOptions}');
    debugPrint('schedules=${schedules}');

    // Guard: ensure we have drivers and schedules loaded and valid
    final hasValidDrivers = driverOptions.isNotEmpty && driverOptions.any((d) => d['driver_id'] != null);
    final hasValidSchedules = schedules.isNotEmpty && schedules.any((s) => s['schedule_id'] != null);

    if (!hasValidDrivers) {
      debugPrint('No valid drivers available to assign');
      _showDeferredSnackBar('No drivers available. Create drivers first.');
      return;
    }
    if (!hasValidSchedules) {
      debugPrint('No valid schedules available to assign');
      // Offer to create a schedule in place so admin can continue the assign flow.
      final create = await showDialog<bool?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No schedules'),
          content: const Text('No valid schedules available to assign. Create a schedule now?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Create')),
          ],
        ),
      );

      if (create == true) {
        // Open the full ManageSchedule screen so admin can create schedules.
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageScheduleScreen()));
        // After returning, reload data and try again.
        await _loadData();
        // Re-evaluate whether schedules are available; if yes, re-open this dialog for the same shuttle.
        final hasSchedulesNow = schedules.isNotEmpty && schedules.any((s) => s['schedule_id'] != null);
        if (hasSchedulesNow) {
          // Re-open the assign dialog for the same shuttle index
          return _showAssignDriverDialog(index);
        } else {
          _showDeferredSnackBar('No schedules were created');
          return;
        }
      }
      // If user cancelled, just return.
      return;
    }

    // Use dynamic to support numeric or string/UUID ids
    dynamic selectedDriverId = driverOptions.isNotEmpty ? (driverOptions.firstWhere((d) => d['driver_id'] != null, orElse: () => {})['driver_id']) : null;
    dynamic selectedScheduleId = schedules.isNotEmpty ? (schedules.firstWhere((s) => s['schedule_id'] != null, orElse: () => {})['schedule_id']) : null;

    final outerContext = context;

    final assigned = await showDialog<bool?>(
      context: outerContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          bool assignWorking = false;

           // We need to capture and mutate selectedDriverId/selectedScheduleId and assignWorking inside the dialog.
           return AlertDialog(
            title: const Text('Assign Driver'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<dynamic>(
                  initialValue: (() {
                    final ids = driverOptions.map((d) => d['driver_id']?.toString()).whereType<String>().toSet();
                    return (selectedDriverId != null && ids.contains(selectedDriverId.toString())) ? selectedDriverId : null;
                  })(),
                  items: driverOptions
                      .map((d) => DropdownMenuItem<dynamic>(
                            value: d['driver_id'],
                            child: Text((d['name'] ?? '').toString().isNotEmpty ? (d['name'] ?? '').toString() : 'Driver ${d['driver_id']}'),
                          ))
                      .toList(),
                  onChanged: (v) => setStateDialog(() {
                    selectedDriverId = v;
                  }),
                  decoration: const InputDecoration(labelText: 'Driver'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<dynamic>(
                  initialValue: (() {
                    final ids = schedules.map((s) => s['schedule_id']?.toString()).whereType<String>().toSet();
                    return (selectedScheduleId != null && ids.contains(selectedScheduleId.toString())) ? selectedScheduleId : null;
                  })(),
                  items: schedules
                      .map((s) => DropdownMenuItem<dynamic>(value: s['schedule_id'], child: Text('Schedule ${s['schedule_id']}')))
                      .toList(),
                  onChanged: (v) => setStateDialog(() {
                    selectedScheduleId = v;
                  }),
                  decoration: const InputDecoration(labelText: 'Schedule'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              Builder(builder: (ctx) {
                return ElevatedButton(
                  onPressed: (!assignWorking && selectedDriverId != null && selectedScheduleId != null)
                      ? () async {
                          setStateDialog(() => assignWorking = true);
                          try {
                            // Prepare the id we'll send; seeding logic below may replace this value.
                            dynamic driverIdToSend = selectedDriverId;
                            debugPrint('Creating assignment: driverId=$selectedDriverId shuttleId=${shuttle.id} scheduleId=$selectedScheduleId');

                            // Before creating an assignment, check for duplicates (same shuttle, schedule, and date)
                            final String dateOnly = DateTime.now().toIso8601String().split('T').first;
                            try {
                              final existingAssignments = await _service.getDriverAssignments();
                              final duplicate = existingAssignments.firstWhere(
                                (a) {
                                  final sid = (a['shuttle_id'] ?? a['shuttleId'] ?? a['shuttle'])?.toString();
                                  final scid = (a['schedule_id'] ?? a['scheduleId'] ?? a['schedule'])?.toString();
                                  final ad = (a['assignment_date'] ?? a['assignmentDate'] ?? a['date'])?.toString() ?? '';
                                  return sid == shuttle.id!.toString() && scid == selectedScheduleId!.toString() && ad.startsWith(dateOnly);
                                },
                                orElse: () => {},
                              );

                              if (duplicate.isNotEmpty) {
                                setStateDialog(() => assignWorking = false);
                                await showDialog<void>(
                                  context: context,
                                  builder: (ctx2) => AlertDialog(
                                    title: const Text('Assignment exists'),
                                    content: const Text('An assignment already exists for this shuttle and schedule today.'),
                                    actions: [TextButton(onPressed: () => Navigator.of(ctx2).pop(), child: const Text('OK'))],
                                  ),
                                );
                                return;
                              }
                            } catch (e) {
                              debugPrint('Warning: failed to fetch existing assignments for duplicate check: $e');
                            }

                            // Ensure the driver exists in backend; if not, attempt to seed from user
                            try {
                              Map<String, dynamic>? backendMatch;
                              try {
                                final backendDrivers = await _service.getDrivers();
                                for (final bd in backendDrivers) {
                                  final bdDriverId = bd['driver_id'] ?? bd['driverId'] ?? bd['id'];
                                  final bdUserId = bd['user_id'] ?? bd['userId'] ?? bd['user'];
                                  if (bdDriverId != null && bdDriverId.toString() == driverIdToSend.toString()) {
                                    backendMatch = bd;
                                    break;
                                  }
                                  if (bdUserId != null && bdUserId.toString() == driverIdToSend.toString()) {
                                    backendMatch = bd;
                                    break;
                                  }
                                }
                              } catch (e) {
                                debugPrint('Warning: failed to fetch backend drivers for existence check: $e');
                              }

                              if (backendMatch != null && backendMatch.isNotEmpty) {
                                driverIdToSend = backendMatch['driver_id'] ?? backendMatch['driverId'] ?? backendMatch['id'] ?? driverIdToSend;
                                debugPrint('Using existing backend driver id: $driverIdToSend');
                              } else {
                                // try to extract user id from selected option
                                dynamic userIdForSeeding;
                                Map<String, dynamic> sel = {};
                                try {
                                  sel = driverOptions.firstWhere((d) => d['driver_id']?.toString() == selectedDriverId?.toString() || d['user_id']?.toString() == selectedDriverId?.toString(), orElse: () => {});
                                  if (sel.isNotEmpty) userIdForSeeding = sel['user_id'] ?? sel['driver_id'];
                                } catch (_) {}

                                if (userIdForSeeding != null) {
                                  try {
                                    debugPrint('No backend driver found; attempting to create driver from user id: $userIdForSeeding');
                                    final seeded = await _service.createDriverFromUser(userIdForSeeding);
                                    final seededId = seeded['driver_id'] ?? seeded['driverId'] ?? seeded['id'];
                                    if (seededId == null) throw Exception('Seeded driver response did not include an id');
                                    driverIdToSend = seededId;
                                    try {
                                      final name = (sel['name'] ?? 'Driver ${seededId}').toString();
                                      driverOptions.add({'driver_id': seededId, 'user_id': userIdForSeeding, 'name': name});
                                    } catch (_) {}
                                    debugPrint('Seeded driver id: $driverIdToSend');
                                  } catch (e) {
                                    setStateDialog(() => assignWorking = false);
                                    await showDialog<void>(
                                      context: context,
                                      builder: (ctx2) => AlertDialog(
                                        title: const Text('Failed to create driver'),
                                        content: Text('Could not create a driver record for the selected user: $e'),
                                        actions: [TextButton(onPressed: () => Navigator.of(ctx2).pop(), child: const Text('OK'))],
                                      ),
                                    );
                                    return;
                                  }
                                } else {
                                  debugPrint('No user id available to seed driver; proceeding with provided driver id: $driverIdToSend');
                                }
                              }

                              final assignment = await _service.createDriverAssignment(driverId: driverIdToSend, shuttleId: shuttle.id!, scheduleId: selectedScheduleId!);
                              debugPrint('Assignment created: $assignment');

                              final driverRow = driverOptions.firstWhere((d) => d['driver_id']?.toString() == driverIdToSend.toString(), orElse: () => {});
                              final driverName = (driverRow.isNotEmpty ? (driverRow['name'] as String?) : null) ?? 'Driver ${driverIdToSend}';
                              setState(() {
                                shuttleAssignedDriver[shuttle.id!] = driverName;
                              });

                              await _loadData();
                              Navigator.of(context).pop(true);
                            } catch (e, st) {
                              debugPrint('Failed to create assignment: $e');
                              debugPrintStack(label: 'AssignDriverStack', stackTrace: st);
                              Navigator.of(context).pop(false);
                              debugPrint('Assign driver error: ${e.toString()}');
                            }
                          } finally {
                            try {
                              setStateDialog(() => assignWorking = false);
                            } catch (_) {}
                          }
                        }
                      : null,
                  child: assignWorking
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                      : const Text('Assign'),
                );
              }),
            ],
          );
        },
      ),
    );

    // Show snackbar from outer context based on dialog result
    if (!mounted) return;
    if (assigned == true) {
      _showDeferredSnackBar('Driver assigned');
    } else if (assigned == false) {
      _showDeferredSnackBar('Failed to assign driver');
    }
  }

  void _showDebugDialog() async {
    // fetch raw HTTP responses for drivers and schedules
    Map<String, dynamic> driversRaw = {'status': 'n/a', 'body': 'n/a'};
    Map<String, dynamic> schedulesRaw = {'status': 'n/a', 'body': 'n/a'};
    try {
      driversRaw = await _service.debugGetRaw('drivers/getAll');
    } catch (e) {
      driversRaw = {'status': 'error', 'body': e.toString()};
    }
    try {
      schedulesRaw = await _service.debugGetRaw('schedules/getAll');
    } catch (e) {
      schedulesRaw = {'status': 'error', 'body': e.toString()};
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug: drivers & schedules'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Parsed driverOptions:'),
              const SizedBox(height: 6),
              Text(const JsonEncoder.withIndent('  ').convert(driverOptions)),
              const SizedBox(height: 12),
              const Text('Parsed schedules:'),
              const SizedBox(height: 6),
              Text(const JsonEncoder.withIndent('  ').convert(schedules)),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Raw drivers response:'),
              const SizedBox(height: 6),
              Text('URL: ${driversRaw['url'] ?? 'n/a'}'),
              Text('Status: ${driversRaw['status'] ?? 'n/a'}'),
              const SizedBox(height: 6),
              Text((driversRaw['body'] ?? '').toString()),
              const SizedBox(height: 12),
              const Text('Raw schedules response:'),
              const SizedBox(height: 6),
              Text('URL: ${schedulesRaw['url'] ?? 'n/a'}'),
              Text('Status: ${schedulesRaw['status'] ?? 'n/a'}'),
              const SizedBox(height: 6),
              Text((schedulesRaw['body'] ?? '').toString()),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      ),
    );
  }

  void _showManageSchedulesDialog() async {
    final routeController = TextEditingController();
    final departureController = TextEditingController();
    final arrivalController = TextEditingController();
    String selectedDay = 'Monday';

    final outerContext = context;

    final result = await showDialog<String?>(
       context: outerContext,
       builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
         bool manageWorking = false;
         // new: selectedRouteId and create-route controllers
         dynamic selectedRouteId = routes.isNotEmpty ? routes.first['route_id'] : null;
         final createRouteNameController = TextEditingController();
         final createRouteDescController = TextEditingController();

         return AlertDialog(
           title: const Text('Manage Schedules'),
           content: SingleChildScrollView(
             child: Column(
               mainAxisSize: MainAxisSize.min,
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 const Text('Existing schedules:'),
                 const SizedBox(height: 8),
                 if (schedules.isEmpty) const Text('No schedules yet'),
                 if (schedules.isNotEmpty)
                   SizedBox(
                     height: 120,
                     child: ListView.builder(
                       itemCount: schedules.length,
                       itemBuilder: (ctx, i) {
                         final s = schedules[i];
                         return ListTile(
                           dense: true,
                           title: Text('Schedule ${s['schedule_id'] ?? s['scheduleId'] ?? i}'),
                           subtitle: Text(const JsonEncoder.withIndent('  ').convert(s)),
                         );
                       },
                     ),
                   ),
                 const Divider(),
                 const SizedBox(height: 8),
                 const Text('Existing routes:'),
                 const SizedBox(height: 8),
                 if (routes.isEmpty) const Text('No routes yet'),
                 if (routes.isNotEmpty)
                   SizedBox(
                     height: 100,
                     child: ListView.builder(
                       itemCount: routes.length,
                       itemBuilder: (ctx, i) {
                         final r = routes[i];
                         return ListTile(
                           dense: true,
                           title: Text(r['name']?.toString() ?? 'Route ${r['route_id'] ?? i}'),
                           subtitle: Text('ID: ${r['route_id']}'),
                         );
                       },
                     ),
                   ),
                 const Divider(),
                 const SizedBox(height: 8),
                 const Text('Create route'),
                 const SizedBox(height: 8),
                 TextField(controller: createRouteNameController, decoration: const InputDecoration(labelText: 'Route name')),
                 TextField(controller: createRouteDescController, decoration: const InputDecoration(labelText: 'Description (optional)')),
                 const SizedBox(height: 8),
                 ElevatedButton(
                     onPressed: () async {
                       if (manageWorking) return;
                       final name = createRouteNameController.text.trim();
                       final desc = createRouteDescController.text.trim();
                       if (name.isEmpty) {
                         // small delayed notification so we don't try to show overlays during the same pointer event
                         Future.delayed(const Duration(milliseconds: 200), () {
                           if (!mounted) return;
                           _showDeferredSnackBar('Enter route name');
                         });
                         return;
                       }
                       setStateDialog(() => manageWorking = true);
                       try {
                         final created = await _service.createRoute(name: name, description: desc.isEmpty ? null : desc);
                         debugPrint('[ManageShuttles] Created route: $created');
                         await _loadData();
                         // attempt to set the selected route to the newly created id if present
                         final newId = created['route_id'] ?? created['routeId'] ?? created['id'];
                         setStateDialog(() => selectedRouteId = newId ?? selectedRouteId);
                         // notify after a short delay to avoid device update conflicts
                         Future.delayed(const Duration(milliseconds: 200), () {
                           if (!mounted) return;
                           _showDeferredSnackBar('Route created');
                         });
                       } catch (e) {
                         debugPrint('[ManageShuttles] Failed to create route: $e');
                         _showDeferredSnackBar('Failed to create route: $e');
                       } finally {
                         try {
                           setStateDialog(() => manageWorking = false);
                         } catch (_) {}
                       }
                     },
                     child: manageWorking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('Create Route')),
                 const Divider(),
                 const SizedBox(height: 8),
                 const Text('Create schedule'),
                 const SizedBox(height: 8),
                 // If routes are available, allow selecting one; otherwise fall back to entering route id
                 if (routes.isNotEmpty) ...[
                   DropdownButtonFormField<dynamic>(
                     initialValue: (() {
                       final ids = routes.map((r) => r['route_id']?.toString()).whereType<String>().toSet();
                       return (selectedRouteId != null && ids.contains(selectedRouteId.toString())) ? selectedRouteId : null;
                     })(),
                     items: routes
                         .map((r) => DropdownMenuItem<dynamic>(value: r['route_id'], child: Text(r['name']?.toString() ?? r['route_id'].toString())))
                         .toList(),
                     onChanged: (v) => setStateDialog(() => selectedRouteId = v),
                     decoration: const InputDecoration(labelText: 'Route'),
                   ),
                   const SizedBox(height: 8),
                 ] else ...[
                   TextField(controller: routeController, decoration: const InputDecoration(labelText: 'Route ID (numeric or string)')),
                 ],

                TextField(controller: departureController, decoration: const InputDecoration(labelText: 'Departure ISO (YYYY-MM-DDTHH:MM:SS)')),
                TextField(controller: arrivalController, decoration: const InputDecoration(labelText: 'Arrival ISO (YYYY-MM-DDTHH:MM:SS)')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedDay,
                  items: ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday']
                      .map((d) => DropdownMenuItem<String>(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => selectedDay = v ?? selectedDay),
                  decoration: const InputDecoration(labelText: 'Day of week'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
            ElevatedButton(
              onPressed: () async {
                if (manageWorking) return;
                final routeIdRaw = routes.isNotEmpty ? (selectedRouteId ?? routeController.text.trim()) : routeController.text.trim();
                final departure = departureController.text.trim();
                final arrival = arrivalController.text.trim();
                if ((routeIdRaw == null || routeIdRaw.toString().isEmpty) || departure.isEmpty || arrival.isEmpty) {
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (!mounted) return;
                    _showDeferredSnackBar('Fill route, departure and arrival');
                  });
                  return;
                }
                setStateDialog(() => manageWorking = true);
                try {
                  debugPrint('[ManageShuttles] Creating schedule route=$routeIdRaw departure=$departure arrival=$arrival day=$selectedDay');
                  final created = await _service.createSchedule(
                    routeId: int.tryParse(routeIdRaw.toString()) ?? routeIdRaw,
                    departureTime: departure,
                    arrivalTime: arrival,
                    dayOfWeek: selectedDay,
                  );
                  debugPrint('[ManageShuttles] Created schedule: $created');
                  await _loadData();
                  Navigator.of(context).pop('schedule_created');
                 } catch (e) {
                  debugPrint('[ManageShuttles] Failed to create schedule: $e');
                  // close dialog with an error marker; outer caller will show snackbar
                  Navigator.of(context).pop('schedule_error:$e');
                 } finally {
                   try {
                     setStateDialog(() => manageWorking = false);
                   } catch (_) {}
                 }
               },
              child: manageWorking ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,valueColor:AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('Create'),
            ),
          ],
        );
      }),
    );

    // After dialog completes, show snackbars from outer context
    if (!mounted) return;
    if (result == 'schedule_created') {
      _showDeferredSnackBar('Schedule created');
    } else if (result != null && result.startsWith('schedule_error:')) {
      final msg = result.substring('schedule_error:'.length);
      _showDeferredSnackBar('Failed to create schedule: $msg');
    }
   }
}
