import 'package:flutter/material.dart';
import 'package:shuttle_tracker/models/shuttle_model.dart';
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
  String? _statusFilter;  // Added status filter
  String? _typeFilter;    // Added type filter

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

  Widget _buildActionButtons(BoxConstraints constraints) {
    final buttons = [
      ElevatedButton.icon(
        icon: const Icon(Icons.add),
        label: const Text('Add Shuttle'),
        onPressed: () => _showAddShuttleDialog(context),
      ),
      ElevatedButton.icon(
        icon: const Icon(Icons.schedule),
        label: const Text('Manage Schedules'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManageScheduleScreen()),
        ),
      ),
      ElevatedButton.icon(
        icon: const Icon(Icons.route),
        label: const Text('Manage Routes'),
        onPressed: () => _showManageRoutesDialog(context),
      ),
    ];

    return constraints.maxWidth < 600
        ? Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            children: buttons,
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: buttons.map((button) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: button,
            )).toList(),
          );
  }

  Widget _buildFilterSection(BoxConstraints constraints) {
    final filters = [
      DropdownButton<String>(
        hint: const Text('Filter by Status'),
        value: _statusFilter,
        items: [
          const DropdownMenuItem(value: null, child: Text('All Statuses')),
          ...statuses.map((status) => DropdownMenuItem(
            value: status['status_id']?.toString(),
            child: Text(status['status_name'] ?? status['name'] ?? 'Status ${status['status_id']}'),
          )),
        ],
        onChanged: (value) => setState(() => _statusFilter = value),
      ),
      const SizedBox(width: 16),
      DropdownButton<String>(
        hint: const Text('Filter by Type'),
        value: _typeFilter,
        items: [
          const DropdownMenuItem(value: null, child: Text('All Types')),
          ...types.map((type) => DropdownMenuItem(
            value: type['type_id']?.toString(),
            child: Text(type['type_name'] ?? type['name'] ?? 'Type ${type['type_id']}'),
          )),
        ],
        onChanged: (value) => setState(() => _typeFilter = value),
      ),
    ];

    return constraints.maxWidth < 600
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: filters,
          )
        : Row(children: filters);
  }

  Widget _buildShuttlesList(BoxConstraints constraints) {
    // Apply filters to the shuttle list
    List<Shuttle> filteredShuttles = shuttles;

    if (_statusFilter != null) {
      filteredShuttles = filteredShuttles.where((shuttle) =>
        shuttle.statusId.toString() == _statusFilter
      ).toList();
    }

    if (_typeFilter != null) {
      filteredShuttles = filteredShuttles.where((shuttle) =>
        shuttle.typeId.toString() == _typeFilter
      ).toList();
    }

    if (filteredShuttles.isEmpty) {
      return const Center(child: Text('No shuttles found'));
    }

    return constraints.maxWidth < 800
        ? ListView.builder(
            itemCount: filteredShuttles.length,
            itemBuilder: (context, index) => _buildShuttleCard(filteredShuttles[index], compact: true),
          )
        : GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.maxWidth > 1200 ? 3 : 2,
              childAspectRatio: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: filteredShuttles.length,
            itemBuilder: (context, index) => _buildShuttleCard(filteredShuttles[index], compact: false),
          );
  }

  Widget _buildShuttleCard(Shuttle shuttle, {required bool compact}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${shuttle.make} ${shuttle.model}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Plate: ${shuttle.licensePlate}'),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'assign', child: Text('Assign Driver')),
                    const PopupMenuItem(value: 'schedule', child: Text('Schedule')),
                    const PopupMenuItem(value: 'maintenance', child: Text('Maintenance')),
                  ],
                  onSelected: (value) => _handleShuttleAction(value, shuttle),
                ),
              ],
            ),
            if (!compact) ...[
              const Divider(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(shuttle.statusName ?? 'Status ${shuttle.statusId}')),
                  Chip(label: Text('${shuttle.capacity} seats')),
                if (shuttle.id != null)
                  Chip(label: Text('Driver: ${shuttleAssignedDriver[shuttle.id] ?? 'Unknown'}')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  Future<void> _showAddShuttleDialog(BuildContext context) async {
    final _formKey = GlobalKey<FormState>();
    final makeController = TextEditingController();
    final modelController = TextEditingController();
    final yearController = TextEditingController();
    final capacityController = TextEditingController();
    final plateController = TextEditingController();
    int selectedTypeId = types.isNotEmpty ? types.first['type_id'] as int : 1;
    int selectedStatusId = statuses.isNotEmpty ? statuses.first['status_id'] as int : 1;

    // Capture the outer context to use for SnackBars (dialog builder shadows context)
    final outerContext = context;

    final dialogResult = await showDialog<String?>(
      context: outerContext,
      builder: (context) => AlertDialog(
        title: const Text('Add Shuttle'),
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
                  items: types.map((t) => DropdownMenuItem<int>(value: t['type_id'] as int, child: Text((t['type_name'] ?? '').toString()))).toList(),
                  onChanged: (v) => selectedTypeId = v ?? selectedTypeId,
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                DropdownButtonFormField<int>(
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
                make: makeController.text,
                model: modelController.text,
                year: int.tryParse(yearController.text) ?? 0,
                capacity: int.tryParse(capacityController.text) ?? 0,
                licensePlate: plateController.text,
                statusId: selectedStatusId,
                typeId: selectedTypeId,
              );

              try {
                final created = await _service.createShuttle(newShuttle);
                setState(() => shuttles.insert(0, created));
                // return a marker so the outer caller can show the snackbar safely
                Navigator.of(context).pop('shuttle_added');
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
    } else if (dialogResult != null && dialogResult.startsWith('shuttle_error:')) {
      final msg = dialogResult.substring('shuttle_error:'.length);
      _showDeferredSnackBar('Failed to save shuttle: $msg');
    }
  }

  Future<void> _showEditShuttleDialog(int index) async {
    final shuttle = shuttles[index];
    final _formKey = GlobalKey<FormState>();
    final makeController = TextEditingController(text: shuttle.make);
    final modelController = TextEditingController(text: shuttle.model);
    final yearController = TextEditingController(text: shuttle.year.toString());
    final capacityController = TextEditingController(text: shuttle.capacity.toString());
    final plateController = TextEditingController(text: shuttle.licensePlate);
    int selectedTypeId = shuttle.typeId;
    int selectedStatusId = shuttle.statusId;

    // Capture the outer context to use for SnackBars
    final outerContext = context;

    final dialogResult = await showDialog<String?>(
      context: outerContext,
      builder: (context) => AlertDialog(
        title: const Text('Edit Shuttle'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: makeController,
                  decoration: const InputDecoration(labelText: 'Make'),
                  validator: (v) => v == null || v.isEmpty ? 'Enter make' : null,
                ),
                TextFormField(
                  controller: modelController,
                  decoration: const InputDecoration(labelText: 'Model'),
                  validator: (v) => v == null || v.isEmpty ? 'Enter model' : null,
                ),
                TextFormField(
                  controller: yearController,
                  decoration: const InputDecoration(labelText: 'Year'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty ? 'Enter year' : null,
                ),
                TextFormField(
                  controller: capacityController,
                  decoration: const InputDecoration(labelText: 'Capacity'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty ? 'Enter capacity' : null,
                ),
                TextFormField(
                  controller: plateController,
                  decoration: const InputDecoration(labelText: 'License Plate'),
                  validator: (v) => v == null || v.isEmpty ? 'Enter plate' : null,
                ),
                DropdownButtonFormField<int>(
                  initialValue: selectedTypeId,
                  items: types.map((t) => DropdownMenuItem<int>(
                    value: t['type_id'] as int,
                    child: Text((t['type_name'] ?? t['name'] ?? '').toString()),
                  )).toList(),
                  onChanged: (v) => selectedTypeId = v ?? selectedTypeId,
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                DropdownButtonFormField<int>(
                  initialValue: selectedStatusId,
                  items: statuses.map((s) => DropdownMenuItem<int>(
                    value: s['status_id'] as int,
                    child: Text((s['status_name'] ?? s['name'] ?? '').toString()),
                  )).toList(),
                  onChanged: (v) => selectedStatusId = v ?? selectedStatusId,
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;

              final updatedShuttle = Shuttle(
                id: shuttle.id,
                make: makeController.text,
                model: modelController.text,
                year: int.tryParse(yearController.text) ?? 0,
                capacity: int.tryParse(capacityController.text) ?? 0,
                licensePlate: plateController.text,
                statusId: selectedStatusId,
                typeId: selectedTypeId,
                statusName: shuttle.statusName,
                typeName: shuttle.typeName,
              );

              try {
                final updated = await _service.updateShuttle(shuttle.id!, updatedShuttle);
                setState(() => shuttles[index] = updated);
                Navigator.of(context).pop('shuttle_updated');
              } catch (e) {
                Navigator.of(context).pop('shuttle_error:$e');
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    // Show snackbars from the outer context
    if (!mounted) return;
    if (dialogResult == 'shuttle_updated') {
      _showDeferredSnackBar('Shuttle updated successfully');
    } else if (dialogResult != null && dialogResult.startsWith('shuttle_error:')) {
      final msg = dialogResult.substring('shuttle_error:'.length);
      _showDeferredSnackBar('Failed to update shuttle: $msg');
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

  void _handleShuttleAction(String action, Shuttle shuttle) {
    switch (action) {
      case 'edit':
        final index = shuttles.indexOf(shuttle);
        if (index != -1) {
          _showEditShuttleDialog(index);
        }
        break;
      case 'assign':
        final index = shuttles.indexOf(shuttle);
        if (index != -1) {
          _showAssignDriverDialog(index);
        }
        break;
      case 'schedule':
        _showManageSchedulesDialog();
        break;
      case 'maintenance':
        final index = shuttles.indexOf(shuttle);
        if (index != -1) {
          _markMaintenance(index);
        }
        break;
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



  Future<void> _showManageRoutesDialog(BuildContext context) async {
    final createRouteNameController = TextEditingController();
    final createRouteDescController = TextEditingController();
    bool manageWorking = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Manage Routes'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Existing routes:'),
                const SizedBox(height: 8),
                if (routes.isEmpty)
                  const Text('No routes yet')
                else
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: routes.length,
                      itemBuilder: (context, index) {
                        final route = routes[index];
                        return ListTile(
                          title: Text(route['name']?.toString() ?? 'Route ${route['route_id']}'),
                          subtitle: Text('ID: ${route['route_id']}'),
                        );
                      },
                    ),
                  ),
                const Divider(),
                const SizedBox(height: 16),
                const Text('Create new route:'),
                const SizedBox(height: 8),
                TextField(
                  controller: createRouteNameController,
                  decoration: const InputDecoration(labelText: 'Route name'),
                ),
                TextField(
                  controller: createRouteDescController,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: manageWorking ? null : () async {
                final name = createRouteNameController.text.trim();
                if (name.isEmpty) {
                  _showDeferredSnackBar('Enter route name');
                  return;
                }

                setStateDialog(() => manageWorking = true);
                try {
                  await _service.createRoute(
                    name: name,
                    description: createRouteDescController.text.trim(),
                  );
                  await _loadData();
                  _showDeferredSnackBar('Route created successfully');
                  Navigator.of(context).pop();
                } catch (e) {
                  _showDeferredSnackBar('Failed to create route: $e');
                } finally {
                  setStateDialog(() => manageWorking = false);
                }
              },
              child: manageWorking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Create Route'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManageSchedulesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Manage Schedules'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: schedules.length,
              itemBuilder: (context, index) {
                final schedule = schedules[index];
                return ListTile(
                  title: Text('Schedule ID: ${schedule['schedule_id']}'),
                  subtitle: Text('Details: ${schedule['details'] ?? 'No details'}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteSchedule(schedule['schedule_id']),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSchedule(dynamic scheduleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: Text('Are you sure you want to delete this schedule?'),
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
      await _service.deleteSchedule(scheduleId);
      setState(() {
        schedules.removeWhere((s) => s['schedule_id'] == scheduleId);
      });
      _showDeferredSnackBar('Schedule deleted');
    } catch (e) {
      _showDeferredSnackBar('Failed to delete schedule: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
        title: const Text('Manage Shuttles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildActionButtons(constraints),
                      const SizedBox(height: 16),
                      _buildFilterSection(constraints),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildShuttlesList(constraints),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
