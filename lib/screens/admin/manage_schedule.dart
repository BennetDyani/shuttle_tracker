// dart
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/shuttle_service.dart';
import 'package:intl/intl.dart';
import '../../models/shuttle_model.dart';

class ManageScheduleScreen extends StatefulWidget {
  const ManageScheduleScreen({super.key});

  @override
  State<ManageScheduleScreen> createState() => _ManageScheduleScreenState();
}

class _ManageScheduleScreenState extends State<ManageScheduleScreen> {
  final ShuttleService _shuttleService = ShuttleService();
  List<dynamic> schedules = [];
  bool isLoading = true;
  String? errorMessage;

  // Cache route id -> route name so schedules can show a human-readable route
  final Map<String, String> _routeNames = {};

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
  }

  // Normalizes varying schedule representations (Map, model, etc.) into a consistent Map
  Map<String, dynamic> _normalizeSchedule(dynamic s) {
    if (s == null) return {};
    if (s is Map) {
      final id = (s['id'] ?? s['scheduleId'] ?? s['schedule_id'])?.toString() ?? '';

      // Try to determine route name. Backend may return only a route_id (route_id or routeId)
      String route = '';
      final routeIdCandidate = s['route'] ?? s['routeId'] ?? s['route_id'] ?? s['route_id'];
      if (routeIdCandidate != null) {
        final rid = routeIdCandidate.toString();
        route = _routeNames[rid] ?? rid;
      }
      // Fallback: maybe the schedule already contains a route name field
      route = route.isNotEmpty
          ? route
          : ((s['routeName'] ?? s['route_name'] ?? s['name'] ?? (s['route'] is Map ? (s['route']['name'] ?? s['route']['title']) : null))?.toString() ?? '');

      final departure = (s['departureTime'] ?? s['departure_time'] ?? s['start'] ?? s['start_time'] ?? s['departure'])?.toString() ?? '';
      final arrival = (s['arrivalTime'] ?? s['arrival_time'] ?? s['end'] ?? s['end_time'] ?? s['arrival'])?.toString() ?? '';
      final day = (s['dayOfWeek'] ?? s['day_of_week'] ?? s['day'] ?? s['weekday'])?.toString() ?? '';
      final status = (s['status'] ?? 'Pending')?.toString() ?? 'Pending';
      final assignment = s['assignment'] ?? s['assigned'] ?? s['driverAssignment'] ?? s['driver_assignment'];
      return {
        'id': id,
        'route': route,
        'routeId': (s['routeId'] ?? s['route_id'] ?? s['route'])?.toString(),
        'departureTime': departure,
        'arrivalTime': arrival,
        'day': day,
        'status': status,
        'assignment': assignment,
        'raw': s,
      };
    } else {
      // Try to read properties from model objects (best-effort)
      try {
        final id = (s.id?.toString() ?? s.scheduleId?.toString() ?? s.toString());
        final route = (s.routeName ?? s.name ?? s.route?.name ?? '').toString();
        final departure = (s.departureTime ?? s.start ?? '').toString();
        final arrival = (s.arrivalTime ?? s.end ?? '').toString();
        final day = (s.dayOfWeek ?? s.day ?? '').toString();
        final status = (s.status ?? 'Pending').toString();
        final assignment = s.assignment ?? null;
        return {
          'id': id,
          'route': route,
          'departureTime': departure,
          'arrivalTime': arrival,
          'day': day,
          'status': status,
          'assignment': assignment,
          'raw': s,
        };
      } catch (_) {
        return {
          'id': s.toString(),
          'route': s.toString(),
          'departureTime': '',
          'arrivalTime': '',
          'day': '',
          'status': 'Pending',
          'raw': s,
        };
      }
    }
  }

  Future<void> _fetchSchedules() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      // Fetch routes first so we can map route_id -> route name
      try {
        final fetchedRoutes = await _shuttleService.getRoutes();
        for (final r in fetchedRoutes) {
          // r is Map<String,dynamic> per ShuttleService, read keys safely
          final id = (r['id'] ?? r['routeId'] ?? r['route_id'])?.toString() ?? '';
          final name = (r['name'] ?? r['routeName'] ?? r['route_name'] ?? r['title'])?.toString() ?? id;
          if (id.isNotEmpty) _routeNames[id] = name;
        }
      } catch (e) {
        debugPrint('[ManageSchedule] failed to load routes: $e');
      }

      final fetched = await _shuttleService.getSchedules();
      setState(() {
        // Normalize all schedules so UI can depend on consistent keys
        schedules = (fetched as List<dynamic>).map((e) => _normalizeSchedule(e)).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  String _routeNameFromSchedule(dynamic s) {
    if (s is Map) {
      return (s['route'] ??
              s['routeName'] ??
              (s['raw'] is Map ? ((s['raw'] as Map)['routeName'] ?? (s['raw'] as Map)['name']) : null) ??
              '')
          .toString();
    }
    // fallback
    return s?.toString() ?? '';
  }

  String _formatTime(String? t) {
    if (t == null || t.trim().isEmpty) return '';
    try {
      // Try parsing as HH:mm first
      final parsed = DateFormat.Hm().parseLoose(t);
      return DateFormat.Hm().format(parsed);
    } catch (_) {
      try {
        // Fallback to ISO DateTime.parse (handles full timestamps)
        final dt = DateTime.parse(t);
        return DateFormat.Hm().format(dt);
      } catch (_) {
        return t;
      }
    }
  }

  Future<void> _openCreateScheduleDialog() async {
    List<Map<String, dynamic>> routes = [];
    String? selectedRouteId;
    String? dayOfWeek;
    TimeOfDay? departure;
    TimeOfDay? arrival;
    bool loadingRoutes = true;

    try {
      final fetched = await _shuttleService.getRoutes();
      routes = (fetched as List<dynamic>).map((r) {
        if (r is Map) {
          final id = (r['id'] ?? r['routeId'] ?? r['route_id'])?.toString() ?? '';
          final name = (r['name'] ?? r['routeName'] ?? id)?.toString() ?? id;
          return {'id': id, 'name': name};
        } else {
          try {
            final id = r.id?.toString() ?? r.toString();
            final name = (r.name?.toString() ?? id);
            return {'id': id, 'name': name};
          } catch (_) {
            final val = r.toString();
            return {'id': val, 'name': val};
          }
        }
      }).where((m) => (m['id']?.isNotEmpty ?? false)).toList();
      loadingRoutes = false;
    } catch (e) {
      loadingRoutes = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load routes: $e')));
      });
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
            final dialogContext = context;
            final t = await showTimePicker(context: dialogContext, initialTime: TimeOfDay.now());
            if (!dialogContext.mounted) return;
            if (t != null) setState(() => isDeparture ? departure = t : arrival = t);
          }

          return AlertDialog(
            title: const Text('Create Schedule'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (loadingRoutes) const Center(child: CircularProgressIndicator())
                  else Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Route'),
                      const SizedBox(height: 6),
                      DropdownButton<String>(
                        value: selectedRouteId,
                        hint: const Text('Select route'),
                        isExpanded: true,
                        items: routes.map((r) => DropdownMenuItem<String>(value: r['id'], child: Text(r['name'] ?? r['id'] ?? ''))).toList(),
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
                  final now = DateTime.now();
                  final dep = DateTime(now.year, now.month, now.day, departure!.hour, departure!.minute);
                  final arr = DateTime(now.year, now.month, now.day, arrival!.hour, arrival!.minute);
                  final depStr = DateFormat.Hm().format(dep);
                  final arrStr = DateFormat.Hm().format(arr);

                  final dialogContext = context;
                  try {
                    final routeName = routes.firstWhere((r) => (r['id'] ?? '') == (selectedRouteId ?? ''), orElse: () => {})['name'] ?? selectedRouteId ?? '';
                    final temp = {'route': routeName, 'departureTime': depStr, 'arrivalTime': arrStr, 'status': 'Pending', 'day': dayOfWeek};
                    setState(() => schedules.insert(0, temp));

                    dynamic routeIdToSend;
                    final parsed = int.tryParse(selectedRouteId ?? '');
                    if (parsed != null) routeIdToSend = parsed; else routeIdToSend = selectedRouteId;

                    final created = await _shuttleService.createSchedule(routeId: routeIdToSend, departureTime: depStr, arrivalTime: arrStr, dayOfWeek: dayOfWeek!);

                    if (!dialogContext.mounted) return;

                    final normalizedCreated = _normalizeSchedule(created);

                    setState(() {
                      final idx = schedules.indexWhere((a) => (a['status'] == 'Pending' && (a['departureTime'] == depStr || a['start'] == depStr) && (a['arrivalTime'] == arrStr || a['end'] == arrStr)));
                      if (idx != -1) {
                        schedules[idx] = normalizedCreated;
                      } else {
                        schedules.insert(0, normalizedCreated);
                      }
                    });

                    Navigator.of(dialogContext).pop();

                    await showDialog(
                      context: dialogContext,
                      builder: (ctx) {
                        return AlertDialog(
                          title: const Text('Schedule created'),
                          content: SingleChildScrollView(child: Text('Created schedule:\n${normalizedCreated.toString()}')),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                            TextButton(
                              onPressed: () async {
                                Navigator.of(ctx).pop();
                                await _openAssignDialog(normalizedCreated);
                              },
                              child: const Text('Assign now'),
                            ),
                          ],
                        );
                      },
                    );
                  } catch (e) {
                    setState(() {
                      final idx = schedules.indexWhere((a) => a['status'] == 'Pending' && (a['departureTime'] == depStr || a['start'] == depStr) && (a['arrivalTime'] == arrStr || a['end'] == arrStr));
                      if (idx != -1) schedules.removeAt(idx);
                    });
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Failed to create schedule: $e')));
                    }
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

  Future<void> _openAssignDialog(dynamic schedule) async {
    try {
      final drivers = await _shuttleService.getDrivers();
      final rawShuttles = await _shuttleService.getShuttles();

      // Fetch users so we can resolve driver -> user.name/email (backend returns driver rows with user_id)
      List<Map<String, dynamic>> users = [];
      try {
        users = await _shuttleService.fetchUsers();
      } catch (e) {
        debugPrint('[ManageSchedule] failed to fetch users: $e');
      }
      final Map<String, Map<String, dynamic>> usersById = {};
      for (final Map<String, dynamic> u in users) {
        final uid = (u['userId'] ?? u['id'] ?? u['user_id'])?.toString() ?? '';
        if (uid.isNotEmpty) usersById[uid] = u;
      }

      if (!mounted) return;

      debugPrint('[ManageSchedule] raw drivers count=${drivers.length}');
      if (drivers.isNotEmpty) debugPrint('[ManageSchedule] raw drivers sample=${drivers.first}');

      final List<Map<String, String>> driverItems = (drivers as List<dynamic>).map<Map<String, String>>((d) {
        final Map<String, dynamic> dm = d as Map<String, dynamic>;
        String id = (dm['driverId'] ?? dm['driver_id'] ?? dm['id'])?.toString() ?? '';

        // Try to resolve user info via user_id foreign key (drivers table likely has 'user_id')
        final userId = (dm['user'] is Map ? (dm['user']['userId'] ?? dm['user']['user_id'] ?? dm['user']['id']) : (dm['userId'] ?? dm['user_id'] ?? dm['user']))?.toString();

        Map<String, dynamic>? userMap;
        if (userId != null && userId.isNotEmpty) userMap = usersById[userId];

        String label = '';
        if (userMap != null) {
          final first = (userMap['name'] ?? userMap['first_name'] ?? userMap['firstName'])?.toString() ?? '';
          final last = (userMap['surname'] ?? userMap['last_name'] ?? userMap['lastName'])?.toString() ?? '';
          final email = (userMap['email'] ?? userMap['emailAddress'])?.toString() ?? '';
          label = [first, last].where((s) => s.trim().isNotEmpty).join(' ');
          if (label.isEmpty) label = email.isNotEmpty ? email : (userMap['userId'] ?? userMap['id'])?.toString() ?? id;
        }

        // Fallbacks if user data not available
        if (label.isEmpty) label = (dm['name'] ?? dm['fullName'] ?? dm['username'])?.toString() ?? '';
        if (label.isEmpty && dm['user'] is Map) {
          final u = dm['user'] as Map<String, dynamic>;
          label = (u['name'] ?? ((u['first_name'] ?? '') is String ? ((u['first_name'] ?? '') + ' ' + (u['last_name'] ?? '')) : ''))?.toString().trim() ?? '';
          if (label.isEmpty) label = (u['email'] ?? u['emailAddress'] ?? '')?.toString() ?? '';
        }
        if (label.isEmpty) label = id;

        return {'id': id, 'label': label};
      }).where((m) => (m['id']?.isNotEmpty ?? false)).toList();

      if (driverItems.isEmpty) {
        // Show a debug dialog with raw driver/user payloads to help diagnose missing drivers
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                title: const Text('No drivers available'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Raw drivers response:'),
                      const SizedBox(height: 6),
                      Text(jsonEncode(drivers).toString()),
                      const SizedBox(height: 12),
                      const Text('Raw users response:'),
                      const SizedBox(height: 6),
                      Text(jsonEncode(users).toString()),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                  TextButton(onPressed: () {
                    Navigator.of(ctx).pop();
                    _openAssignDialog(schedule);
                  }, child: const Text('Retry')),
                ],
              );
            },
          );
        });
        return;
      }

      final List<Map<String, String>> shuttleItems = (rawShuttles as List<dynamic>).map<Map<String, String>>((s) {
        String id = '';
        String label = '';
        if (s is Map) {
          id = (s['id'] ?? s['shuttleId'] ?? s['shuttle_id'])?.toString() ?? '';
          label = (s['plate'] ?? s['plateNumber'] ?? s['licensePlate'])?.toString() ?? '';
          if (label.isEmpty) label = id;
        } else {
          try {
            id = (s is Shuttle) ? (s.id?.toString() ?? '') : s.toString();
            label = (s is Shuttle) ? (s.licensePlate.toString()) : s.toString();
          } catch (_) {
            final val = s.toString();
            id = val;
            label = val;
          }
        }
        return {'id': id, 'label': label};
      }).where((m) => (m['id']?.isNotEmpty ?? false)).toList();

      debugPrint('[ManageSchedule] driverItems count=${driverItems.length}');
      debugPrint('[ManageSchedule] shuttleItems count=${shuttleItems.length}');

      String? selectedDriverId = driverItems.isNotEmpty ? driverItems.first['id'] : null;
      String? selectedShuttleId = shuttleItems.isNotEmpty ? shuttleItems.first['id'] : null;

      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Assign Driver & Shuttle'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  key: const Key('assign_driver_dropdown'),
                  value: selectedDriverId,
                  hint: const Text('Select driver'),
                  isExpanded: true,
                  items: driverItems.map((di) => DropdownMenuItem<String>(value: di['id'], child: Text(di['label'] ?? di['id'] ?? ''))).toList(),
                  onChanged: (v) => setState(() => selectedDriverId = v),
                ),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  key: const Key('assign_shuttle_dropdown'),
                  value: selectedShuttleId,
                  hint: const Text('Select shuttle'),
                  isExpanded: true,
                  items: shuttleItems.map((si) => DropdownMenuItem<String>(value: si['id'], child: Text(si['label'] ?? si['id'] ?? ''))).toList(),
                  onChanged: (v) => setState(() => selectedShuttleId = v),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              ElevatedButton(onPressed: () async {
                if (selectedDriverId == null || selectedShuttleId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select driver and shuttle')));
                  return;
                }
                Navigator.of(ctx).pop();

                dynamic driverIdToSend = int.tryParse(selectedDriverId!) ?? selectedDriverId;
                dynamic shuttleIdToSend = int.tryParse(selectedShuttleId!) ?? selectedShuttleId;
                dynamic scheduleIdToSend = schedule['id'] ?? schedule['schedule_id'] ?? schedule['scheduleId'] ?? schedule;

                try {
                  final assignDialogContext = ctx;

                  // Prevent duplicate assignments for the same shuttle + schedule on the same date
                  final String dateOnly = DateTime.now().toIso8601String().split('T').first;
                  try {
                    final existing = await _shuttleService.getDriverAssignments();
                    final dup = existing.firstWhere(
                      (a) {
                        final sid = (a['shuttle_id'] ?? a['shuttleId'] ?? a['shuttle'])?.toString();
                        final scid = (a['schedule_id'] ?? a['scheduleId'] ?? a['schedule'])?.toString();
                        final ad = (a['assignment_date'] ?? a['assignmentDate'] ?? a['date'])?.toString() ?? '';
                        return sid == shuttleIdToSend.toString() && scid == scheduleIdToSend.toString() && ad.startsWith(dateOnly);
                      },
                      orElse: () => {},
                    );

                    if (dup.isNotEmpty) {
                      // Duplicate found: inform user and abort
                      if (assignDialogContext.mounted) {
                        await showDialog<void>(
                          context: assignDialogContext,
                          builder: (ctx2) => AlertDialog(
                            title: const Text('Assignment exists'),
                            content: const Text('An assignment already exists for this shuttle and schedule today.'),
                            actions: [TextButton(onPressed: () => Navigator.of(ctx2).pop(), child: const Text('OK'))],
                          ),
                        );
                      }
                      return;
                    }
                  } catch (e) {
                    debugPrint('[ManageSchedule] Warning: failed to fetch existing assignments for duplicate check: $e');
                    // Continue — we still attempt to create the assignment if the check fails
                  }

                  final assignment = await _shuttleService.createDriverAssignment(driverId: driverIdToSend, shuttleId: shuttleIdToSend, scheduleId: scheduleIdToSend);

                  if (!assignDialogContext.mounted) return;

                  setState(() {
                    final idx = schedules.indexWhere((s) => (s['id'] ?? s['schedule_id'] ?? s['scheduleId']) == (schedule['id'] ?? schedule['schedule_id'] ?? schedule['scheduleId']));
                    if (idx != -1) {
                      schedules[idx] = {...schedules[idx], 'assignment': assignment, 'status': 'Assigned'};
                    }
                  });

                  if (!assignDialogContext.mounted) return;
                  await showDialog(
                    context: assignDialogContext,
                    builder: (ctx2) => AlertDialog(
                      title: const Text('Assigned'),
                      content: SingleChildScrollView(child: Text('Assignment created:\n${assignment.toString()}')),
                      actions: [TextButton(onPressed: () => Navigator.of(ctx2).pop(), child: const Text('OK'))],
                    ),
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to assign: $e')));
                  }
                }
              }, child: const Text('Assign')),
            ],
          );
        }),
      );
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load drivers or shuttles: $e')));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Handle system/back button the same way as the AppBar leading button.
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Navigator.pushReplacementNamed(context, '/admin/dashboard');
        }
        // We handled navigation (pop or replace) so prevent default framework pop.
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () {
              // If there's a previous route, pop to it. Otherwise replace with the admin dashboard.
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.pushReplacementNamed(context, '/admin/dashboard');
              }
            },
          ),
          title: const Text('Manage Schedules'),
          centerTitle: true,
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Create Schedule',
          onPressed: _openCreateScheduleDialog,
          child: const Icon(Icons.add),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(child: Text('Error: $errorMessage'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: schedules.length,
                    itemBuilder: (context, index) {
                      final s = schedules[index];
                      final route = _routeNameFromSchedule(s);
                      final start = _formatTime((s['departureTime'] ?? s['start'] ?? s['start_time'])?.toString());
                      final end = _formatTime((s['arrivalTime'] ?? s['end'] ?? s['end_time'])?.toString());
                      final day = (s['day'] ?? s['dayOfWeek'] ?? '').toString();
                      final status = (s['status'] ?? 'Pending').toString();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(child: Text(route, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                                Text(status, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                const Icon(Icons.access_time, size: 16),
                                const SizedBox(width: 6),
                                Text('${start.isEmpty ? '-' : start} - ${end.isEmpty ? '-' : end}'),
                                const Spacer(),
                                Text(day.isEmpty ? '-' : day),
                              ]),
                              const SizedBox(height: 8),
                              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                TextButton(onPressed: () => _openAssignDialog(s), child: const Text('Assign')),
                                const SizedBox(width: 8),
                                TextButton(onPressed: () {
                                  // Optionally open details or edit in future
                                }, child: const Text('Details')),
                              ])
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
