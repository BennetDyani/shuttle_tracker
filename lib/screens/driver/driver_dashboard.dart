import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/APIService.dart';
import '../../services/endpoints.dart';
import '../../services/logout_helper.dart';
import '../../models/driver_model/Driver.dart';
import '../../models/shuttle_model.dart';
import '../../services/shuttle_service.dart';
import 'live_route_tracking.dart';
import 'schedule_screen.dart';
import 'stop_screen.dart';
import 'report_maintenance.dart';

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

  // Load the driver's assignment and resolve shuttle details (label + capacity), schedule, and route info
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
          // ShuttleService.getShuttles() returns List<Shuttle> from shuttle_model.dart
          final List<Shuttle> shuttles = await _shuttleService.getShuttles();
          for (final s in shuttles) {
            // shuttle_model uses 'id' field which can be null
            final sid = s.id?.toString() ?? '';
            if (sid.isNotEmpty && sid == shuttleIdRaw) {
              shuttleLabel = s.licensePlate;
              shuttleCap = s.capacity.toString();
              break;
            }
          }
        } catch (e) {
          debugPrint('[DriverDashboard] Error fetching shuttles: $e');
        }
      }

      // Resolve schedule and route info
      final scheduleIdRaw = (matched['scheduleId'] ?? matched['schedule_id'] ?? matched['schedule'])?.toString() ?? '';
      if (scheduleIdRaw.isNotEmpty) {
        try {
          final schedules = await _shuttleService.getSchedules();
          Map<String, dynamic>? scheduleMatch;
          for (final s in schedules) {
            final sid = (s['schedule_id'] ?? s['scheduleId'] ?? s['id'])?.toString();
            if (sid == scheduleIdRaw) {
              scheduleMatch = s;
              break;
            }
          }

          if (scheduleMatch != null) {
            // Add schedule times to the matched assignment
            matched['departure_time'] = scheduleMatch['departure_time'] ?? scheduleMatch['departureTime'] ?? scheduleMatch['start_time'];
            matched['arrival_time'] = scheduleMatch['arrival_time'] ?? scheduleMatch['arrivalTime'] ?? scheduleMatch['end_time'];
            matched['day_of_week'] = scheduleMatch['day_of_week'] ?? scheduleMatch['dayOfWeek'] ?? scheduleMatch['day'];

            // Resolve route info from schedule
            final routeIdRaw = (scheduleMatch['route_id'] ?? scheduleMatch['routeId'] ?? scheduleMatch['route'])?.toString() ?? '';
            if (routeIdRaw.isNotEmpty) {
              try {
                final routes = await _shuttleService.getRoutes();
                for (final r in routes) {
                  final rid = (r['route_id'] ?? r['routeId'] ?? r['id'])?.toString();
                  if (rid == routeIdRaw) {
                    matched['route_name'] = r['name'] ?? r['routeName'] ?? r['route_name'] ?? 'Unknown Route';
                    matched['route_description'] = r['description'] ?? r['route_description'] ?? '';
                    break;
                  }
                }
              } catch (_) {
                // ignore route fetch errors
              }
            }
          }
        } catch (_) {
          // ignore schedule fetch errors
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_isLoadingName ? 'Driver Dashboard' : 'Hi, $_displayName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => performGlobalLogout(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.maxWidth < 600 ? 16.0 : 24.0;
          return SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (errorMessage != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                errorMessage!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              if (driverNotFound && userRow != null) ...[
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _quickCreateDriver,
                                  child: const Text('Create Driver Profile'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    else ...[
                      _buildStatusSection(constraints),
                      SizedBox(height: constraints.maxWidth < 600 ? 16 : 24),
                      _buildActionButtons(constraints),
                      SizedBox(height: constraints.maxWidth < 600 ? 16 : 24),
                      _buildCurrentAssignment(constraints),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusSection(BoxConstraints constraints) {
    final isSmallScreen = constraints.maxWidth < 600;
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
        child: constraints.maxWidth < 600
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDriverInfo(),
                  const Divider(height: 32),
                  _buildShuttleInfo(),
                ],
              )
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildDriverInfo()),
                    const VerticalDivider(width: 48, thickness: 1),
                    Expanded(child: _buildShuttleInfo()),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDriverInfo() {
    // Get name from driver's user or user row
    String driverName = '';
    if (driver != null && driver!.user.userId > 0) {
      final first = driver!.user.name;
      final last = driver!.user.surname;
      driverName = '$first $last'.trim();
    }
    if (driverName.isEmpty && userRow != null) {
      final first = (userRow!['first_name'] ?? userRow!['name'] ?? '').toString();
      final last = (userRow!['last_name'] ?? userRow!['surname'] ?? '').toString();
      driverName = '$first $last'.trim();
    }

    final email = driver?.user.email ?? userRow?['email']?.toString() ?? 'Not available';
    final phone = driver?.phoneNumber ?? driver?.user.phoneNumber ?? userRow?['phone_number']?.toString() ?? 'Not provided';
    final license = driver?.licenseNumber ?? driver?.driverLicense ?? 'Not available';
    final status = driver?.status ?? 'Active';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Driver Information',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (driverName.isNotEmpty) ...[
          _buildInfoRow('Name', driverName),
          const SizedBox(height: 8),
        ],
        _buildInfoRow('Email', email),
        const SizedBox(height: 8),
        _buildInfoRow('Phone', phone),
        const SizedBox(height: 8),
        _buildInfoRow('License', license),
        const SizedBox(height: 8),
        _buildInfoRow('Status', status),
      ],
    );
  }

  Widget _buildShuttleInfo() {
    final hasShuttle = assignedShuttleLabel != '-' && assignedShuttleLabel.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assigned Shuttle',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (!hasShuttle) ...[
          _buildInfoRow('Status', 'No shuttle assigned'),
          const SizedBox(height: 8),
          const Text(
            'Please contact administrator to assign a shuttle.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ] else ...[
          _buildInfoRow('License Plate', assignedShuttleLabel),
          const SizedBox(height: 8),
          _buildInfoRow('Capacity', assignedShuttleCapacity != '-' ? '$assignedShuttleCapacity seats' : 'Unknown'),
          const SizedBox(height: 8),
          _buildInfoRow('Status', shuttleStatus),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: shuttleStatus == 'Available' ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: shuttleStatus == 'Available' ? Colors.green.shade200 : Colors.orange.shade200,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  shuttleStatus == 'Available' ? Icons.check_circle : Icons.warning,
                  size: 16,
                  color: shuttleStatus == 'Available' ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  shuttleStatus == 'Available' ? 'Ready for service' : 'Requires attention',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: shuttleStatus == 'Available' ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BoxConstraints constraints) {
    final isSmallScreen = constraints.maxWidth < 600;
    final buttonWidth = (constraints.maxWidth - (isSmallScreen ? 32 : 48)) / (isSmallScreen ? 2 : 4);
    final buttonSpacing = isSmallScreen ? 12.0 : 16.0;

    return Wrap(
      spacing: buttonSpacing,
      runSpacing: buttonSpacing,
      alignment: WrapAlignment.center,
      children: [
        _actionButton(
          'Start Route',
          Icons.play_arrow,
          Colors.green,
          buttonWidth,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveRouteTrackingScreen())),
        ),
        _actionButton(
          'View Schedule',
          Icons.schedule,
          Colors.blue,
          buttonWidth,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScheduleScreen())),
        ),
        _actionButton(
          'Stop Points',
          Icons.location_on,
          Colors.orange,
          buttonWidth,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StopScreen())),
        ),
        _actionButton(
          'Report Issue',
          Icons.report_problem,
          Colors.red,
          buttonWidth,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportMaintenanceScreen())),
        ),
      ],
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, double width, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(77)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentAssignment(BoxConstraints constraints) {
    final isSmallScreen = constraints.maxWidth < 600;
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Assignment',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: isSmallScreen ? 16 : 24),
            constraints.maxWidth < 600
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildAssignmentDetails(),
                  )
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildAssignmentDetails()
                          .map((widget) => Expanded(child: widget))
                          .toList(),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? time) {
    if (time == null || time.trim().isEmpty) return 'Not set';
    try {
      // Try parsing as HH:mm first
      final parts = time.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          final period = hour >= 12 ? 'PM' : 'AM';
          final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
          return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
        }
      }
      return time;
    } catch (_) {
      return time;
    }
  }

  List<Widget> _buildAssignmentDetails() {
    if (activeAssignment == null) {
      return [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No Active Assignment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You have not been assigned to a route yet. Please contact your administrator.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ];
    }

    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Route Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Route', activeAssignment?['route_name'] ?? 'Not assigned'),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Day',
            activeAssignment?['day_of_week'] ?? 'Not set',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Departure',
            _formatTime(activeAssignment?['departure_time']?.toString()),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Arrival',
            _formatTime(activeAssignment?['arrival_time']?.toString()),
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assignment Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Service', inService ? 'In Service' : 'Not in Service'),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Shuttle',
            assignedShuttleLabel != '-' ? assignedShuttleLabel : 'Not assigned',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Schedule ID',
            activeAssignment?['schedule_id']?.toString() ??
            activeAssignment?['scheduleId']?.toString() ??
            'Not set',
          ),
        ],
      ),
    ];
  }
}
