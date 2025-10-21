import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'live_route_tracking.dart';
import 'schedule_screen.dart';
import 'stop_screen.dart';
import 'report_maintenance.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import '../../services/APIService.dart';
import '../../models/driver_model/Driver.dart';
import '../../services/logout_helper.dart';
import '../../services/endpoints.dart';
import '../../services/shuttle_service.dart';
import '../../models/shuttle_model.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  bool inService = false;
  String shuttleStatus = 'Available'; // or 'Under Maintenance'

  Driver? driver;
  Map<String, dynamic>? userRow; // store fetched user info so we can show it when driver row missing
  bool isLoading = true;
  String? errorMessage;
  bool driverNotFound = false;

  // Shuttle/assignment state
  final ShuttleService _shuttleService = ShuttleService();
  String assignedShuttleLabel = '-';
  String assignedShuttleCapacity = '-';
  Map<String, dynamic>? activeAssignment;
  bool assignmentLoading = false;

  // Greeting name state
  String _displayName = '';
  bool _isLoadingName = true;

  @override
  void initState() {
    super.initState();
    _fetchDriver();
    _loadName();
  }

  Future<void> _loadName() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uidStr = auth.userId;
      if (uidStr == null || uidStr.isEmpty) return;
      final uid = int.tryParse(uidStr);
      if (uid == null) return;
      final user = await APIService().fetchUserById(uid);
      // store user in state for dashboard fallback display
      userRow = Map<String, dynamic>.from(user);
      final first = (user['first_name'] ?? user['name'] ?? '').toString();
      final last = (user['last_name'] ?? user['surname'] ?? '').toString();
      final combined = ('$first $last').trim();
      if (!mounted) return;
      setState(() {
        _displayName = combined.isEmpty ? (user['email'] ?? '') as String? ?? '' : combined;
      });
    } catch (e) {
      // silently fail; keep default title
    } finally {
      if (mounted) setState(() => _isLoadingName = false);
    }
  }

  Future<void> _fetchDriver() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      driver = null;
      userRow = null;
      // reset assignment info while loading
      assignedShuttleLabel = '-';
      assignedShuttleCapacity = '-';
      activeAssignment = null;
    });
    try {
      // Determine current user's email via AuthProvider -> fetchUserById
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uidStr = auth.userId;
      if (uidStr == null || uidStr.isEmpty) throw Exception('Not logged in');
      final uid = int.tryParse(uidStr);
      if (uid == null) throw Exception('Invalid user id');

      final user = await APIService().fetchUserById(uid);
      userRow = Map<String, dynamic>.from(user);
      final email = (user['email'] ?? '') as String;
      if (email.isEmpty) {
        setState(() {
          errorMessage = 'No email available for the current user.';
          isLoading = false;
        });
        return;
      }

      try {
        // Prefer the dedicated helper which returns a Map or throws ApiException
        final fetchedDriver = await APIService().fetchDriverByEmail(email);
        setState(() {
          driver = Driver.fromJson(fetchedDriver);
          isLoading = false;
          driverNotFound = false;
        });
        // After we have a driver row, load their active assignment and shuttle info
        try {
          await _loadAssignmentForDriver(driver!.driverId);
        } catch (_) {
          // ignore assignment load errors; UI will show placeholders
        }
      } on ApiException catch (apiErr) {
        // Backend returned a non-2xx status. If 404, show friendly message; otherwise surface error.
        if (apiErr.statusCode == 404) {
          setState(() {
            errorMessage = 'Driver profile not found for this account. Please create one or contact an administrator.';
            isLoading = false;
            driverNotFound = true;
          });
        } else {
          setState(() {
            errorMessage = apiErr.toString();
            isLoading = false;
            driverNotFound = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // Load the driver's assignment and resolve shuttle details (label + capacity)
  Future<void> _loadAssignmentForDriver(int driverId) async {
    if (mounted) setState(() => assignmentLoading = true);
    try {
      final assignments = await _shuttleService.getDriverAssignments();
      // Find an assignment that belongs to this driver. Accept different key names.
      Map<String, dynamic>? matched;
      for (final Map<String, dynamic> a in assignments) {
        final aid = (a['driverId'] ?? a['driver_id'] ?? a['driver'])?.toString() ?? '';
        if (aid.isEmpty) continue;
        if (int.tryParse(aid) == driverId || aid == driverId.toString()) {
          matched = a;
          break;
        }
      }
      if (matched == null) {
        setState(() {
          activeAssignment = null;
          assignedShuttleLabel = '-';
          assignedShuttleCapacity = '-';
        });
        return;
      }

      // Resolve shuttle info
      final shuttleIdRaw = (matched['shuttleId'] ?? matched['shuttle_id'] ?? matched['shuttle'])?.toString() ?? '';
      String shuttleLabel = '-';
      String shuttleCap = '-';
      if (shuttleIdRaw.isNotEmpty) {
        try {
          // ShuttleService.getShuttles() returns List<Shuttle>; handle Shuttle objects directly
          final List<Shuttle> shuttles = await _shuttleService.getShuttles();
          for (final s in shuttles) {
            final sid = s.id?.toString() ?? '';
            if (sid.isNotEmpty && sid == shuttleIdRaw) {
              shuttleLabel = s.licensePlate;
              shuttleCap = s.capacity.toString();
              break;
            }
          }
        } catch (_) {
          // ignore shuttle fetch errors
        }
      }

      if (mounted) {
        setState(() {
          activeAssignment = matched;
          assignedShuttleLabel = shuttleLabel;
          assignedShuttleCapacity = shuttleCap;
        });
      }
    } finally {
      if (mounted) setState(() => assignmentLoading = false);
    }
  }

  // Quick create a minimal driver row using the userRow if backend is missing a driver
  Future<void> _quickCreateDriver() async {
    if (userRow == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No user data available to create driver')));
      return;
    }
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final userId = userRow!['user_id'] ?? userRow!['userId'];
      final staffId = userRow!['staff_id'] ?? userRow!['staffId'] ?? '';
      final payload = {
        // include nested user or userId depending on backend flexibility
        'user': {'userId': userId},
        'staffId': staffId,
        'driverLicense': '',
      };
      await APIService().post(Endpoints.driverCreate, payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Driver profile created')));
      await _fetchDriver();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create driver: $msg')));
      setState(() {
        errorMessage = msg;
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dUser = driver?.user;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoadingName ? 'Driver Dashboard' : 'Hi, ${_displayName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              // Confirm logout with the user
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Logout')),
                  ],
                ),
              );
              if (confirm == true) {
                await performGlobalLogout();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DriverSettingsPage()),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // When driver row missing, show user info and CTA to create profile
                      if (driverNotFound) ...[
                        Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('No Driver Profile Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text(errorMessage!, textAlign: TextAlign.left),
                                const SizedBox(height: 12),
                                Text('Account info:', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text('Name: ${userRow == null ? '-' : '${userRow!['first_name'] ?? ''} ${userRow!['last_name'] ?? ''}'.trim()}'),
                                const SizedBox(height: 4),
                                Text('Email: ${userRow?['email'] ?? '-'}'),
                                const SizedBox(height: 4),
                                Text('Staff ID: ${userRow?['staff_id'] ?? '-'}'),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => const DriverProfilePage()),
                                        );
                                      },
                                      icon: const Icon(Icons.edit),
                                      label: const Text('Create / Edit Driver Profile'),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      onPressed: _quickCreateDriver,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Quick Create'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                    ),
                                    const SizedBox(width: 12),
                                    OutlinedButton.icon(
                                      onPressed: _fetchDriver,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(errorMessage!),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _fetchDriver,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Active Assignment Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Add refresh button and optional spinner for assignment loading
                              Row(
                                children: [
                                  const Expanded(child: Text('Active Assignment', style: TextStyle(fontSize: 16, color: Colors.grey))),
                                  if (assignmentLoading) const SizedBox(width: 12),
                                  if (assignmentLoading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                  IconButton(
                                    tooltip: 'Refresh assignment',
                                    icon: const Icon(Icons.refresh, size: 20),
                                    onPressed: driver == null ? null : () async {
                                      if (driver == null) return;
                                      // ensure spinner shows immediately
                                      if (mounted) setState(() => assignmentLoading = true);
                                      try {
                                        await _loadAssignmentForDriver(driver!.driverId);
                                      } finally {
                                        if (mounted) setState(() => assignmentLoading = false);
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Driver: ${dUser?.name ?? "-"} ${dUser?.surname ?? ""}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text('Email: ${dUser?.email ?? "-"}', style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 8),
                              // Show assigned shuttle summary on the Active Assignment card
                              Text('Assigned Shuttle: ${assignedShuttleLabel}', style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('Shuttle Capacity: ${assignedShuttleCapacity}', style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: inService ? Colors.green : Colors.orange,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          inService ? Icons.circle : Icons.circle_outlined,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          inService ? 'In Service' : 'Not Started',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        inService = !inService;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: inService ? Colors.red : Colors.green,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Text(inService ? 'End Shift' : 'Start Shift'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Shuttle Info Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Shuttle Info', style: TextStyle(fontSize: 16, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.badge, color: Colors.blue, size: 28),
                                  const SizedBox(width: 10),
                                  Text('Driver License: ${driver?.driverLicense ?? "-"}', style: const TextStyle(fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Shuttle details come from assignments/shuttle service
                              Text('Assigned Shuttle: ${assignedShuttleLabel}', style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 6),
                              Text('Capacity: ${assignedShuttleCapacity}', style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    shuttleStatus == 'Available' ? Icons.check_circle : Icons.warning,
                                    color: shuttleStatus == 'Available' ? Colors.green : Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    shuttleStatus,
                                    style: TextStyle(
                                      color: shuttleStatus == 'Available' ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Quick Actions Grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.2,
                        children: [
                          _quickAction(context, Icons.map, 'View Route Map', () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const LiveRouteTrackingScreen()),
                            );
                          }),
                          _quickAction(context, Icons.schedule, 'View Schedule', () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const DriverScheduleScreen()),
                            );
                          }),
                          _quickAction(context, Icons.directions_walk, 'View Stops', () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const DriverStopsScreen()),
                            );
                          }),
                          _quickAction(context, Icons.report_problem, 'Report Issue', () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ReportMaintenanceScreen()),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _quickAction(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[50],
        foregroundColor: Colors.blue[900],
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36),
          const SizedBox(height: 10),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
