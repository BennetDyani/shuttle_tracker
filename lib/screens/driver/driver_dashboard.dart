import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/APIService.dart';
import '../../services/endpoints.dart';
import '../../services/logout_helper.dart';
import '../../models/driver_model/Driver.dart';
import '../../models/driver_model/Shuttle.dart';
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
          final List<Shuttle> shuttles = (await _shuttleService.getShuttles()).cast<Shuttle>();
          for (final s in shuttles) {
            final sid = s.shuttleId.toString();
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
    return Scaffold(
      appBar: AppBar(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Driver Information',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildInfoRow('License', driver?.licenseNumber ?? 'Not available'),
        const SizedBox(height: 8),
        _buildInfoRow('Status', driver?.status ?? 'Active'),
        const SizedBox(height: 8),
        _buildInfoRow('Phone', driver?.phoneNumber ?? userRow?['phone_number'] ?? 'Not provided'),
      ],
    );
  }

  Widget _buildShuttleInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assigned Shuttle',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildInfoRow('Shuttle', assignedShuttleLabel),
        const SizedBox(height: 8),
        _buildInfoRow('Capacity', '$assignedShuttleCapacity seats'),
        const SizedBox(height: 8),
        _buildInfoRow('Status', shuttleStatus),
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

  List<Widget> _buildAssignmentDetails() {
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
            'Schedule',
            activeAssignment?['schedule_id'] != null
                ? 'Schedule ${activeAssignment!['schedule_id']}'
                : 'Not assigned',
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Service', inService ? 'In Service' : 'Not in Service'),
          if (activeAssignment != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Start Time', activeAssignment!['start_time'] ?? 'Not set'),
            const SizedBox(height: 8),
            _buildInfoRow('End Time', activeAssignment!['end_time'] ?? 'Not set'),
          ],
        ],
      ),
    ];
  }
}
