import 'package:flutter/material.dart';
import '../../services/APIService.dart';
import '../../services/endpoints.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/shuttle_service.dart';
import 'package:intl/intl.dart';
import '../../models/shuttle_model.dart';

class DriverScheduleScreen extends StatefulWidget {
  const DriverScheduleScreen({super.key});

  @override
  State<DriverScheduleScreen> createState() => _DriverScheduleScreenState();
}

class _DriverScheduleScreenState extends State<DriverScheduleScreen> {
  List<dynamic> assignments = [];
  bool isLoading = true;
  String? errorMessage;
  final ShuttleService _shuttleService = ShuttleService();

  @override
  void initState() {
    super.initState();
    _fetchSchedule();
  }

  // Fetch assignments for the currently logged-in driver (resolve drivers.driver_id)
  Future<void> _fetchSchedule() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uidStr = auth.userId;
      if (uidStr == null || uidStr.isEmpty) throw Exception('Not logged in');

      int driverDbId = 0;
      try {
        final rawDrivers = await _shuttle_service_getDrivers();
        for (final dr in rawDrivers) {
          if (dr is Map<String, dynamic>) {
            final userField = dr['user'] is Map ? (dr['user']['userId'] ?? dr['user']['user_id'] ?? dr['user']['id']) : (dr['userId'] ?? dr['user_id'] ?? dr['user']);
            if (userField != null && userField.toString() == uidStr) {
              driverDbId = int.tryParse((dr['driverId'] ?? dr['driver_id'] ?? dr['id']).toString()) ?? 0;
              break;
            }
          }
        }
      } catch (e) {
        // ignore and fallback
      }

      final int queryId = driverDbId != 0 ? driverDbId : (int.tryParse(uidStr) ?? 0);
      if (queryId == 0) throw Exception('Invalid driver/user id');

      // Fetch assignments for this driver
      final assignmentEndpoint = Endpoints.assignmentsByDriverId(queryId);
      final rawAssignments = await APIService().get(assignmentEndpoint);
      List<dynamic> assignmentsList = [];
      if (rawAssignments is List) assignmentsList = rawAssignments;
      else if (rawAssignments is Map<String, dynamic>) {
        if (rawAssignments['data'] is List) assignmentsList = rawAssignments['data'] as List<dynamic>;
        else if (rawAssignments['assignments'] is List) assignmentsList = rawAssignments['assignments'] as List<dynamic>;
      }

      if (assignmentsList.isEmpty) {
        setState(() {
          assignments = [];
          isLoading = false;
        });
        return;
      }

      // Map routes and shuttles
      final routesRaw = await _shuttle_service_getRoutes();
      final shuttlesRaw = await _shuttle_service_getShuttles();
      // Also fetch drivers so we can display driver name/email
      final driversRaw = await _shuttle_service_getDrivers();
      final Map<String, Map<String, dynamic>> driversById = {};
      for (final d in driversRaw) {
        if (d is Map<String, dynamic>) {
          final did = (d['driverId'] ?? d['driver_id'] ?? d['id'])?.toString() ?? '';
          if (did.isNotEmpty) driversById[did] = d;
        }
      }
      final Map<String, String> routeNames = {};
      for (final r in routesRaw) {
        if (r is Map<String, dynamic>) {
          final id = (r['routeId'] ?? r['route_id'] ?? r['id'])?.toString() ?? '';
          final name = (r['name'] ?? r['routeName'] ?? r['route_name'])?.toString() ?? id;
          if (id.isNotEmpty) routeNames[id] = name;
        }
      }
      // Build shuttle info map: id -> {label, capacity}
      final Map<String, Map<String, dynamic>> shuttleInfo = {};
      for (final s in shuttlesRaw) {
        if (s is Map<String, dynamic>) {
          final id = (s['shuttleId'] ?? s['shuttle_id'] ?? s['id'])?.toString() ?? '';
          final label = (s['licensePlate'] ?? s['license_plate'] ?? s['plate'] ?? s['plateNumber'])?.toString() ?? id;
          final cap = (s['capacity'] ?? s['cap'] ?? s['seats'])?.toString() ?? '';
          if (id.isNotEmpty) shuttleInfo[id] = {'label': label, 'capacity': cap};
        } else if (s is Shuttle) {
          final id = s.id?.toString() ?? '';
          final label = s.licensePlate.toString();
          final cap = s.capacity.toString();
          if (id.isNotEmpty) shuttleInfo[id] = {'label': label, 'capacity': cap};
        }
      }

      final List<dynamic> displayList = [];
      for (final a in assignmentsList) {
        try {
          if (a == null) continue;
          final Map<String, dynamic> am = (a is Map<String, dynamic>) ? a : (a is Map ? Map<String, dynamic>.from(a) : {'assignment_id': a.toString()});
          final scheduleId = (am['scheduleId'] ?? am['schedule_id'] ?? am['schedule'])?.toString() ?? '';
          final shuttleId = (am['shuttleId'] ?? am['shuttle_id'] ?? am['shuttle'])?.toString() ?? '';
          final assignmentDate = (am['assignmentDate'] ?? am['assignment_date'] ?? am['date'])?.toString() ?? '';

          Map<String, dynamic> scheduleObj = {};
          if (scheduleId.isNotEmpty) {
            try {
              final schedRaw = await APIService().get(Endpoints.scheduleReadById(int.tryParse(scheduleId) ?? 0));
              if (schedRaw is Map<String, dynamic>) scheduleObj = schedRaw;
            } catch (_) {}
          }

          final routeId = (scheduleObj['routeId'] ?? scheduleObj['route_id'] ?? scheduleObj['route'])?.toString() ?? '';
          final dep = (scheduleObj['departureTime'] ?? scheduleObj['departure_time'] ?? scheduleObj['start'] ?? scheduleObj['start_time'])?.toString() ?? '';
          final arr = (scheduleObj['arrivalTime'] ?? scheduleObj['arrival_time'] ?? scheduleObj['end'] ?? scheduleObj['end_time'])?.toString() ?? '';

          // Resolve driver info for this assignment (assignment may include driver_id)
          final assignDriverId = (am['driverId'] ?? am['driver_id'] ?? am['driver'])?.toString() ?? '';
          String driverName = '';
          String driverEmail = '';
          if (assignDriverId.isNotEmpty && driversById.containsKey(assignDriverId)) {
            final dd = driversById[assignDriverId]!;
            if (dd['user'] is Map<String, dynamic>) {
              final um = dd['user'] as Map<String, dynamic>;
              driverName = ((um['first_name'] ?? um['firstName'] ?? um['name'])?.toString() ?? '') + ' ' + ((um['last_name'] ?? um['lastName'] ?? um['surname'])?.toString() ?? '');
              driverName = driverName.trim();
              driverEmail = (um['email'] ?? um['emailAddress'])?.toString() ?? '';
            } else {
              driverName = (dd['name'] ?? dd['fullName'] ?? '')?.toString() ?? '';
              driverEmail = (dd['email'] ?? '')?.toString() ?? '';
            }
          }

          final shuttleEntry = (shuttleInfo[shuttleId] ?? {'label': shuttleId, 'capacity': ''});
          final display = {
            'id': scheduleId,
            'route': routeNames[routeId] ?? routeId,
            'start': dep,
            'end': arr,
            'status': 'Assigned',
            'shuttle': shuttleEntry['label'] ?? shuttleId,
            'shuttleCapacity': shuttleEntry['capacity'] ?? '',
            'driverName': driverName,
            'driverEmail': driverEmail,
            'assignmentDate': assignmentDate,
            'rawAssignment': am,
            'rawSchedule': scheduleObj,
          };
          displayList.add(display);
        } catch (_) {
          continue;
        }
      }

      setState(() {
        assignments = displayList;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // Public helper: fetch and display assignments for a driver identified by email
  Future<void> _fetchScheduleForEmail(String email) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      // Find driver DB id by email
      int driverDbId = 0;
      try {
        final rawDrivers = await _shuttle_service_getDrivers();
        for (final dr in rawDrivers) {
          if (dr is Map<String, dynamic>) {
            // Try nested user.email or top-level email-like fields
            final userMap = dr['user'] is Map ? dr['user'] as Map<String, dynamic> : null;
            final drvEmail = (userMap != null)
                ? (userMap['email'] ?? userMap['emailAddress'] ?? userMap['email_address'])
                : (dr['email'] ?? dr['user_email'] ?? dr['userEmail']);
            if (drvEmail != null && drvEmail.toString().toLowerCase() == email.toLowerCase()) {
              driverDbId = int.tryParse((dr['driverId'] ?? dr['driver_id'] ?? dr['id']).toString()) ?? 0;
              break;
            }
          }
        }
      } catch (e) {
        // ignore
      }

      if (driverDbId == 0) throw Exception('Driver with email $email not found');

      // Reuse the main fetch logic by building assignment endpoint and reading schedules
      final assignmentEndpoint = Endpoints.assignmentsByDriverId(driverDbId);
      final rawAssignments = await APIService().get(assignmentEndpoint);
      List<dynamic> assignmentsList = [];
      if (rawAssignments is List) assignmentsList = rawAssignments;
      else if (rawAssignments is Map<String, dynamic>) {
        if (rawAssignments['data'] is List) assignmentsList = rawAssignments['data'] as List<dynamic>;
        else if (rawAssignments['assignments'] is List) assignmentsList = rawAssignments['assignments'] as List<dynamic>;
      }

      // If there are no assignments return empty list
      if (assignmentsList.isEmpty) {
        setState(() {
          assignments = [];
          isLoading = false;
        });
        return;
      }

      // Fetch routes and shuttles once to map ids -> names/labels
      final routesRaw = await _shuttle_service_getRoutes();
      final shuttlesRaw = await _shuttle_service_getShuttles();
      // Also fetch drivers so we can display driver name/email
      final driversRaw = await _shuttle_service_getDrivers();
      final Map<String, Map<String, dynamic>> driversById = {};
      for (final d in driversRaw) {
        if (d is Map<String, dynamic>) {
          final did = (d['driverId'] ?? d['driver_id'] ?? d['id'])?.toString() ?? '';
          if (did.isNotEmpty) driversById[did] = d;
        }
      }
      final Map<String, String> routeNames = {};
      for (final r in routesRaw) {
        if (r is Map<String, dynamic>) {
          final id = (r['routeId'] ?? r['route_id'] ?? r['id'])?.toString() ?? '';
          final name = (r['name'] ?? r['routeName'] ?? r['route_name'])?.toString() ?? id;
          if (id.isNotEmpty) routeNames[id] = name;
        }
      }
      // Build shuttle info map: id -> {label, capacity}
      final Map<String, Map<String, dynamic>> shuttleInfo = {};
      for (final s in shuttlesRaw) {
        if (s is Map<String, dynamic>) {
          final id = (s['shuttleId'] ?? s['shuttle_id'] ?? s['id'])?.toString() ?? '';
          final label = (s['licensePlate'] ?? s['license_plate'] ?? s['plate'] ?? s['plateNumber'])?.toString() ?? id;
          final cap = (s['capacity'] ?? s['cap'] ?? s['seats'])?.toString() ?? '';
          if (id.isNotEmpty) shuttleInfo[id] = {'label': label, 'capacity': cap};
        } else if (s is Shuttle) {
          final id = s.id?.toString() ?? '';
          final label = s.licensePlate.toString();
          final cap = s.capacity.toString();
          if (id.isNotEmpty) shuttleInfo[id] = {'label': label, 'capacity': cap};
        }
      }

      final List<dynamic> displayList = [];
      for (final a in assignmentsList) {
        try {
          if (a == null) continue;
          final Map<String, dynamic> am = (a is Map<String, dynamic>) ? a : (a is Map ? Map<String, dynamic>.from(a) : {'assignment_id': a.toString()});
          final scheduleId = (am['scheduleId'] ?? am['schedule_id'] ?? am['schedule'])?.toString() ?? '';
          final shuttleId = (am['shuttleId'] ?? am['shuttle_id'] ?? am['shuttle'])?.toString() ?? '';
          final assignmentDate = (am['assignmentDate'] ?? am['assignment_date'] ?? am['date'])?.toString() ?? '';

          Map<String, dynamic> scheduleObj = {};
          if (scheduleId.isNotEmpty) {
            try {
              final schedRaw = await APIService().get(Endpoints.scheduleReadById(int.tryParse(scheduleId) ?? 0));
              if (schedRaw is Map<String, dynamic>) scheduleObj = schedRaw;
            } catch (e) {
              // ignore schedule fetch errors
            }
          }

          final routeId = (scheduleObj['routeId'] ?? scheduleObj['route_id'] ?? scheduleObj['route'])?.toString() ?? '';
          final dep = (scheduleObj['departureTime'] ?? scheduleObj['departure_time'] ?? scheduleObj['start'] ?? scheduleObj['start_time'])?.toString() ?? '';
          final arr = (scheduleObj['arrivalTime'] ?? scheduleObj['arrival_time'] ?? scheduleObj['end'] ?? scheduleObj['end_time'])?.toString() ?? '';

          // Resolve driver info for this assignment (assignment may include driver_id)
          final assignDriverId = (am['driverId'] ?? am['driver_id'] ?? am['driver'])?.toString() ?? '';
          String driverName = '';
          String driverEmail = '';
          if (assignDriverId.isNotEmpty && driversById.containsKey(assignDriverId)) {
            final dd = driversById[assignDriverId]!;
            if (dd['user'] is Map<String, dynamic>) {
              final um = dd['user'] as Map<String, dynamic>;
              driverName = ((um['first_name'] ?? um['firstName'] ?? um['name'])?.toString() ?? '') + ' ' + ((um['last_name'] ?? um['lastName'] ?? um['surname'])?.toString() ?? '');
              driverName = driverName.trim();
              driverEmail = (um['email'] ?? um['emailAddress'])?.toString() ?? '';
            } else {
              driverName = (dd['name'] ?? dd['fullName'] ?? '')?.toString() ?? '';
              driverEmail = (dd['email'] ?? '')?.toString() ?? '';
            }
          }

          final shuttleEntry = (shuttleInfo[shuttleId] ?? {'label': shuttleId, 'capacity': ''});
          final display = {
            'id': scheduleId,
            'route': routeNames[routeId] ?? routeId,
            'start': dep,
            'end': arr,
            'status': 'Assigned',
            'shuttle': shuttleEntry['label'] ?? shuttleId,
            'shuttleCapacity': shuttleEntry['capacity'] ?? '',
            'driverName': driverName,
            'driverEmail': driverEmail,
            'assignmentDate': assignmentDate,
            'rawAssignment': am,
            'rawSchedule': scheduleObj,
          };
          displayList.add(display);
        } catch (e) {
          continue;
        }
      }

      setState(() {
        assignments = displayList;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // Helper wrappers so tests or read-methods call shuttle service without duplicate code
  Future<List<dynamic>> _shuttle_service_getDrivers() async => await _shuttleService.getDrivers();
  Future<List<dynamic>> _shuttle_service_getRoutes() async => await _shuttleService.getRoutes();
  Future<List<dynamic>> _shuttle_service_getShuttles() async => (await _shuttleService.getShuttles()).cast<dynamic>();

  Color statusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Completed':
        return Colors.red;
      case 'Upcoming':
      default:
        return Colors.orange;
    }
  }

  IconData statusIcon(String status) {
    switch (status) {
      case 'Active':
        return Icons.circle;
      case 'Completed':
        return Icons.cancel;
      case 'Upcoming':
      default:
        return Icons.pause_circle_filled;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Show knosi@hgtsdriver.cput.com',
            icon: const Icon(Icons.person_search),
            onPressed: () => _fetchScheduleForEmail('knosi@hgtsdriver.cput.com'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        tooltip: 'Create Schedule',
        onPressed: _openCreateScheduleDialog,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text('Error: ' + errorMessage!))
              : ListView.builder(
                  padding: const EdgeInsets.all(20.0),
                  itemCount: assignments.length,
                  itemBuilder: (context, index) {
                    final assignment = assignments[index];
                    // Format assignmentDate if present (ISO timestamp -> YYYY-MM-DD)
                    String formattedAssignmentDate = '';
                    try {
                      final raw = (assignment['assignmentDate'] ?? '')?.toString() ?? '';
                      if (raw.isNotEmpty) {
                        final dt = DateTime.parse(raw);
                        formattedAssignmentDate = DateFormat('yyyy-MM-dd').format(dt);
                      }
                    } catch (_) {
                      // fallback to raw string
                      formattedAssignmentDate = (assignment['assignmentDate'] ?? '').toString();
                    }
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
                                Icon(statusIcon(assignment['status'] as String), color: statusColor(assignment['status'] as String), size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  assignment['route'] as String,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                Text(
                                  assignment['status'] as String,
                                  style: TextStyle(
                                    color: statusColor(assignment['status'] as String),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 18, color: Colors.blueGrey),
                                const SizedBox(width: 6),
                                Text('Start: ${assignment['start']}'),
                                const SizedBox(width: 16),
                                const Icon(Icons.access_time, size: 18, color: Colors.blueGrey),
                                const SizedBox(width: 6),
                                Text('End: ${assignment['end']}'),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text('Shuttle: ${assignment['shuttle']}'),
                            Text('Driver: ${assignment['driverName']}'),
                            Text('Email: ${assignment['driverEmail']}'),
                            Text('Capacity: ${assignment['shuttleCapacity']}'),
                            const SizedBox(height: 8),
                            // Show the assignment date if available (formatted YYYY-MM-DD)
                            if (formattedAssignmentDate.isNotEmpty)
                              Text('Date: $formattedAssignmentDate'),
                          ],
                         ),
                       ),
                     );
                   },
                 ),
     );
   }

  Future<void> _openCreateScheduleDialog() async {
    List<Map<String, dynamic>> routes = [];
    String? selectedRouteId;
    String? dayOfWeek;
    TimeOfDay? departure;
    TimeOfDay? arrival;
    bool loadingRoutes = true;

    // load routes
    try {
      final fetched = await _shuttleService.getRoutes();
      routes = fetched;
      loadingRoutes = false;
    } catch (e) {
      loadingRoutes = false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load routes: $e')));
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          String formatTimeOfDay(TimeOfDay? t) {
            if (t == null) return '';
            final now = DateTime.now();
            final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
            return DateFormat.Hm().format(dt);
          }

          Future<void> pickTime(bool isDeparture) async {
            final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
            if (t != null) setState(() => isDeparture ? departure = t : arrival = t);
          }

          return AlertDialog(
            title: const Text('Create Schedule'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (loadingRoutes) const Center(child: CircularProgressIndicator()) else Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Route'),
                      const SizedBox(height: 6),
                      DropdownButton<String>(
                        value: selectedRouteId,
                        hint: const Text('Select route'),
                        isExpanded: true,
                        items: (() {
                          final items = routes.map((r) {
                            final id = (r['id'] ?? r['routeId'] ?? r['route_id'])?.toString() ?? '';
                            final name = (r['name'] ?? r['routeName'])?.toString() ?? id;
                            return DropdownMenuItem<String>(value: id, child: Text(name));
                          }).where((dm) => (dm.value?.isNotEmpty ?? false)).toList();
                          return items;
                        })(),
                        onChanged: (val) => setState(() => selectedRouteId = val),
                      ),
                      const SizedBox(height: 12),
                      const Text('Day of Week'),
                      const SizedBox(height: 6),
                      DropdownButton<String>(
                        value: dayOfWeek,
                        hint: const Text('Select day'),
                        isExpanded: true,
                        items: ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday']
                            .map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                        onChanged: (v) => setState(() => dayOfWeek = v),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Departure'),
                          const SizedBox(height: 6),
                          ElevatedButton(onPressed: () => pickTime(true), child: Text(departure == null ? 'Pick time' : formatTimeOfDay(departure))),
                        ])),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Arrival'),
                          const SizedBox(height: 6),
                          ElevatedButton(onPressed: () => pickTime(false), child: Text(arrival == null ? 'Pick time' : formatTimeOfDay(arrival))),
                        ])),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedRouteId == null || dayOfWeek == null || departure == null || arrival == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all fields')));
                    return;
                  }
                  // Format times as HH:mm
                  final now = DateTime.now();
                  final dep = DateTime(now.year, now.month, now.day, departure!.hour, departure!.minute);
                  final arr = DateTime(now.year, now.month, now.day, arrival!.hour, arrival!.minute);
                  final depStr = DateFormat.Hm().format(dep);
                  final arrStr = DateFormat.Hm().format(arr);
                  try {
                    // Optimistic insert so user sees the schedule immediately
                    final routeName = routes.firstWhere((r) => ((r['id'] ?? r['routeId'] ?? r['route_id'])?.toString() ?? '') == (selectedRouteId ?? ''), orElse: () => {})['name'] ?? '';
                    final temp = {'route': routeName ?? selectedRouteId, 'start': depStr, 'end': arrStr, 'status': 'Pending', 'day': dayOfWeek};
                    setState(() => assignments.insert(0, temp));

                    // Coerce routeId to int if numeric, else string
                    dynamic routeIdToSend;
                    final parsed = int.tryParse(selectedRouteId ?? '');
                    if (parsed != null) routeIdToSend = parsed; else routeIdToSend = selectedRouteId;

                    final created = await _shuttleService.createSchedule(routeId: routeIdToSend, departureTime: depStr, arrivalTime: arrStr, dayOfWeek: dayOfWeek!);

                    // Replace optimistic entry with actual returned schedule if possible
                    setState(() {
                      // find the first optimistic entry (status Pending)
                      final idx = assignments.indexWhere((a) => a['status'] == 'Pending' && a['start'] == depStr && a['end'] == arrStr);
                      if (idx != -1) assignments[idx] = created;
                    });

                    Navigator.of(context).pop();
                    // Show success dialog with details and assign option
                    await showDialog(
                      context: context,
                      builder: (ctx) {
                        return AlertDialog(
                          title: const Text('Schedule created'),
                          content: SingleChildScrollView(child: Text('Created schedule: ${created.toString()}')),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                            TextButton(
                              onPressed: () async {
                                Navigator.of(ctx).pop();
                                // Offer assign-to-me flow
                                await _assignScheduleToMe(created);
                              },
                              child: const Text('Assign to me'),
                            ),
                          ],
                        );
                      },
                    );
                  } catch (e) {
                    // Remove optimistic entry
                    setState(() {
                      final idx = assignments.indexWhere((a) => a['status'] == 'Pending' && a['start'] == depStr && a['end'] == arrStr);
                      if (idx != -1) assignments.removeAt(idx);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create schedule: $e')));
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _assignScheduleToMe(dynamic schedule) async {
    try {
      // Fetch available shuttles
      final rawShuttles = (await _shuttleService.getShuttles()).cast<dynamic>();
      // Normalize into simple maps with id and label to avoid indexing Shuttle objects in the UI
      final List<Map<String, String>> shuttles = rawShuttles.map<Map<String, String>>((s) {
        if (s is Shuttle) {
          final id = s.id?.toString() ?? '';
          final label = s.licensePlate?.toString() ?? id;
          return {'id': id, 'label': label};
        } else if (s is Map) {
          final id = (s['id'] ?? s['shuttleId'] ?? s['shuttle_id'])?.toString() ?? '';
          final label = (s['plate'] ?? s['plateNumber'] ?? s['licensePlate'] ?? id).toString();
          return {'id': id, 'label': label};
        } else {
          final id = s.toString();
          return {'id': id, 'label': id};
        }
      }).where((m) => (m['id']?.isNotEmpty ?? false)).toList();

      String? selectedShuttleId;
      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Assign Shuttle'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: selectedShuttleId,
                  hint: const Text('Select shuttle'),
                  isExpanded: true,
                  items: shuttles.map((s) {
                    final id = s['id'] ?? '';
                    final label = s['label'] ?? id;
                    return DropdownMenuItem<String>(value: id, child: Text(label));
                  }).where((dm) => (dm.value?.isNotEmpty ?? false)).toList(),
                  onChanged: (v) => setState(() => selectedShuttleId = v),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              ElevatedButton(onPressed: () async {
                if (selectedShuttleId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a shuttle')));
                  return;
                }
                Navigator.of(ctx).pop();
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final uidStr = auth.userId ?? '';
                // Determine the driver's DB id (drivers.driver_id) from the drivers list.
                dynamic driverIdToSend;
                try {
                  final rawDrivers = await _shuttleService.getDrivers();
                  // Try to find a driver record whose user_id matches the auth user id.
                  Map<String, dynamic>? matched;
                  for (final dr in rawDrivers) {
                    if (dr is Map<String, dynamic>) {
                      final userField = dr['user'] is Map
                          ? (dr['user']['userId'] ?? dr['user']['user_id'] ?? dr['user']['id'])
                          : (dr['userId'] ?? dr['user_id'] ?? dr['user']);
                      if (userField != null && userField.toString() == uidStr) {
                        matched = dr;
                        break;
                      }
                    }
                  }
                  if (matched != null) {
                    driverIdToSend = matched['driverId'] ?? matched['driver_id'] ?? matched['id'];
                  } else {
                    // No driver row found. Attempt to seed a driver row for this user via the dev endpoint.
                    try {
                      final seeded = await _shuttleService.createDriverFromUser(uidStr);
                      // seeded may be a Map with driver_id/driverId
                      driverIdToSend = seeded['driverId'] ?? seeded['driver_id'] ?? seeded['id'] ?? seeded;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Created driver record (id: ${driverIdToSend.toString()})')));
                    } catch (seedErr) {
                      // Seeding failed: fall back to previous behavior and warn the user
                      driverIdToSend = int.tryParse(uidStr) ?? uidStr;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to seed driver record: $seedErr — using user id fallback')));
                    }
                  }
                } catch (e) {
                  // On any error while fetching drivers, fallback to auth id (previous behavior)
                  driverIdToSend = int.tryParse(uidStr) ?? uidStr;
                }
                dynamic shuttleIdToSend = int.tryParse(selectedShuttleId!) ?? selectedShuttleId;
                dynamic scheduleIdToSend = schedule['id'] ?? schedule['schedule_id'] ?? schedule['scheduleId'] ?? schedule;
                // call createDriverAssignment
                try {
                  await _shuttleService.createDriverAssignment(driverId: driverIdToSend, shuttleId: shuttleIdToSend, scheduleId: scheduleIdToSend);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assigned successfully')));
                  // Refresh the schedule list from server so the newly-assigned schedule appears
                  await _fetchSchedule();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to assign: $e')));
                }
              }, child: const Text('Assign')),
            ],
          );
        }),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load shuttles: $e')));
    }
  }
}
