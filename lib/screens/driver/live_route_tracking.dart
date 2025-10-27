import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/auth_provider.dart';
import '../../services/APIService.dart';
import '../../services/shuttle_service.dart';
import '../../services/location_ws_service.dart';
import '../student/demo_shuttle_map_screen.dart';

enum ShiftStatus { notStarted, active, ended }
enum RouteStatus { atCampus, leaving, almostThere, arrived, headingBack }

class LiveRouteTrackingScreen extends StatefulWidget {
  const LiveRouteTrackingScreen({super.key});

  @override
  State<LiveRouteTrackingScreen> createState() => _LiveRouteTrackingScreenState();
}

class _LiveRouteTrackingScreenState extends State<LiveRouteTrackingScreen> {
  final ShuttleService _shuttleService = ShuttleService();
  final LocationWebSocketService _locationService = LocationWebSocketService();

  bool isLoading = true;
  String? errorMessage;

  ShiftStatus shiftStatus = ShiftStatus.notStarted;
  RouteStatus routeStatus = RouteStatus.atCampus;

  int? driverId;
  int? shuttleId;
  Map<String, dynamic>? driverAssignment;
  Map<String, dynamic>? routeDetails;

  DateTime? shiftStartTime;
  DateTime? shiftEndTime;

  bool broadcastingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadDriverInfo();
  }

  @override
  void dispose() {
    if (broadcastingLocation) {
      _locationService.disconnect();
    }
    super.dispose();
  }

  Future<void> _loadDriverInfo() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Get current user's driver ID
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uidStr = auth.userId;
      if (uidStr == null || uidStr.isEmpty) {
        throw Exception('Not logged in');
      }
      final uid = int.tryParse(uidStr);
      if (uid == null) throw Exception('Invalid user id');

      final user = await APIService().fetchUserById(uid);
      final email = (user['email'] ?? '') as String;
      if (email.isEmpty) {
        throw Exception('No email available for the current user.');
      }

      // Get driver record
      final fetchedDriver = await APIService().fetchDriverByEmail(email);
      driverId = fetchedDriver['driver_id'] ?? fetchedDriver['driverId'] ?? fetchedDriver['id'];

      if (driverId == null) {
        throw Exception('Driver ID not found');
      }

      // Get driver's assignment
      final assignments = await _shuttleService.getDriverAssignments();
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
          isLoading = false;
          errorMessage = 'No assignment found. Please contact administrator.';
        });
        return;
      }

      driverAssignment = matched;
      shuttleId = int.tryParse((matched['shuttleId'] ?? matched['shuttle_id'] ?? matched['shuttle'])?.toString() ?? '');

      // Get route details
      final scheduleId = (matched['scheduleId'] ?? matched['schedule_id'] ?? matched['schedule'])?.toString();
      if (scheduleId != null && scheduleId.isNotEmpty) {
        final schedules = await _shuttleService.getSchedules();
        for (final s in schedules) {
          final sid = (s['schedule_id'] ?? s['scheduleId'] ?? s['id'])?.toString();
          if (sid == scheduleId) {
            final routeIdRaw = (s['route_id'] ?? s['routeId'] ?? s['route'])?.toString();
            if (routeIdRaw != null && routeIdRaw.isNotEmpty) {
              final routes = await _shuttleService.getRoutes();
              for (final r in routes) {
                final rid = (r['route_id'] ?? r['routeId'] ?? r['id'])?.toString();
                if (rid == routeIdRaw) {
                  routeDetails = r;
                  break;
                }
              }
              break;
            }
          }
        }
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  String _getRouteName() {
    if (routeDetails != null) {
      return (routeDetails!['name'] ??
              routeDetails!['routeName'] ??
              routeDetails!['route_name'] ??
              'Unknown Route').toString();
    }
    return 'Unknown Route';
  }

  Future<void> _startShift() async {
    setState(() => isLoading = true);

    try {
      // Check location permission with improved error handling
      LocationPermission permission;

      try {
        permission = await Geolocator.checkPermission();
      } catch (e) {
        // If checkPermission fails (plugin not initialized), try to proceed anyway
        debugPrint('Warning: Could not check location permission: $e');
        // Try to request permission directly
        try {
          permission = await Geolocator.requestPermission();
        } catch (e2) {
          // If that also fails, log and continue without location
          debugPrint('Warning: Could not request location permission: $e2');
          // Continue without location broadcasting for now
          setState(() {
            shiftStatus = ShiftStatus.active;
            shiftStartTime = DateTime.now();
            routeStatus = RouteStatus.atCampus;
            isLoading = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Shift started (location services unavailable - will use manual updates)'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission is required to start shift');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied. Please enable in settings.');
      }

      // Start WebSocket connection for real-time location broadcasting
      if (driverId != null && shuttleId != null) {
        try {
          _locationService.connect(driverId!, shuttleId!);
          broadcastingLocation = true;
        } catch (e) {
          debugPrint('Warning: Could not start location broadcasting: $e');
          // Continue anyway - shift can still be tracked manually
        }
      }

      setState(() {
        shiftStatus = ShiftStatus.active;
        shiftStartTime = DateTime.now();
        routeStatus = RouteStatus.atCampus;
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(broadcastingLocation
              ? 'Shift started! Location broadcasting enabled.'
              : 'Shift started! (Manual location updates only)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start shift: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _endShift() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Shift'),
        content: const Text('Are you sure you want to end your shift?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End Shift'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);

    try {
      // Disconnect WebSocket
      if (broadcastingLocation) {
        _locationService.disconnect();
        broadcastingLocation = false;
      }

      setState(() {
        shiftStatus = ShiftStatus.ended;
        shiftEndTime = DateTime.now();
        routeStatus = RouteStatus.atCampus;
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shift ended successfully.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to end shift: $e')),
        );
      }
    }
  }

  Future<void> _updateRouteStatus(RouteStatus newStatus) async {
    setState(() => isLoading = true);

    try {
      // Get current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Send status update with location
      if (driverId != null && shuttleId != null) {
        _locationService.sendStatusUpdate(
          driverId!,
          shuttleId!,
          position.latitude,
          position.longitude,
          _getStatusString(newStatus),
        );
      }

      setState(() {
        routeStatus = newStatus;
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated: ${_getStatusDisplayName(newStatus)}'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  String _getStatusString(RouteStatus status) {
    switch (status) {
      case RouteStatus.atCampus:
        return 'AT_CAMPUS';
      case RouteStatus.leaving:
        return 'LEAVING';
      case RouteStatus.almostThere:
        return 'ALMOST_THERE';
      case RouteStatus.arrived:
        return 'ARRIVED';
      case RouteStatus.headingBack:
        return 'HEADING_BACK';
    }
  }

  String _getStatusDisplayName(RouteStatus status) {
    switch (status) {
      case RouteStatus.atCampus:
        return 'At Campus';
      case RouteStatus.leaving:
        return 'Leaving Campus';
      case RouteStatus.almostThere:
        return 'Almost There';
      case RouteStatus.arrived:
        return 'Arrived at Destination';
      case RouteStatus.headingBack:
        return 'Heading Back to Campus';
    }
  }

  IconData _getStatusIcon(RouteStatus status) {
    switch (status) {
      case RouteStatus.atCampus:
        return Icons.home;
      case RouteStatus.leaving:
        return Icons.logout;
      case RouteStatus.almostThere:
        return Icons.near_me;
      case RouteStatus.arrived:
        return Icons.location_on;
      case RouteStatus.headingBack:
        return Icons.keyboard_return;
    }
  }

  Color _getStatusColor(RouteStatus status) {
    switch (status) {
      case RouteStatus.atCampus:
        return Colors.grey;
      case RouteStatus.leaving:
        return Colors.orange;
      case RouteStatus.almostThere:
        return Colors.blue;
      case RouteStatus.arrived:
        return Colors.green;
      case RouteStatus.headingBack:
        return Colors.purple;
    }
  }

  String _formatDuration(DateTime start) {
    final duration = DateTime.now().difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Route'),
        elevation: 0,
        actions: [
          // Demo Mode Button
          IconButton(
            icon: const Icon(Icons.science),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DemoShuttleMapScreen(),
                ),
              );
            },
            tooltip: 'Demo Mode',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadDriverInfo,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Route Info Card
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.route,
                                    color: Theme.of(context).primaryColor,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _getRouteName(),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (shiftStartTime != null) ...[
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Shift Duration',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDuration(shiftStartTime!),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (broadcastingLocation)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.green),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Colors.green,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Live',
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Shift Management Card
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Shift Management',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const SizedBox(height: 16),

                              if (shiftStatus == ShiftStatus.notStarted) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _startShift,
                                    icon: const Icon(Icons.play_arrow, size: 28),
                                    label: const Text(
                                      'Start Shift',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info, color: Colors.blue[700]),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Start your shift to begin broadcasting your location to students in real-time.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (shiftStatus == ShiftStatus.active) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _endShift,
                                    icon: const Icon(Icons.stop, size: 28),
                                    label: const Text(
                                      'End Shift',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.orange[700]),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Shift ended at ${shiftEndTime != null ? "${shiftEndTime!.hour}:${shiftEndTime!.minute.toString().padLeft(2, '0')}" : ""}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.orange[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Route Status Card (only visible during active shift)
                      if (shiftStatus == ShiftStatus.active) ...[
                        const SizedBox(height: 16),
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Route Status',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Update your status so students know where you are',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                _buildStatusButton(
                                  RouteStatus.leaving,
                                  'Leaving Campus',
                                  'Tap when departing from main campus',
                                ),
                                const SizedBox(height: 12),

                                _buildStatusButton(
                                  RouteStatus.almostThere,
                                  'Almost There',
                                  'Tap when approaching destination',
                                ),
                                const SizedBox(height: 12),

                                _buildStatusButton(
                                  RouteStatus.arrived,
                                  'Arrived',
                                  'Tap when you reach the destination',
                                ),
                                const SizedBox(height: 12),

                                _buildStatusButton(
                                  RouteStatus.headingBack,
                                  'Heading Back',
                                  'Tap when returning to campus',
                                ),
                                const SizedBox(height: 12),

                                _buildStatusButton(
                                  RouteStatus.atCampus,
                                  'At Campus',
                                  'Tap when back at campus',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Current Status Display
                      if (shiftStatus == ShiftStatus.active)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _getStatusColor(routeStatus).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getStatusColor(routeStatus).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getStatusIcon(routeStatus),
                                color: _getStatusColor(routeStatus),
                                size: 32,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Current Status',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getStatusDisplayName(routeStatus),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: _getStatusColor(routeStatus),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatusButton(RouteStatus status, String title, String subtitle) {
    final isCurrentStatus = routeStatus == status;
    final color = _getStatusColor(status);

    return Material(
      color: isCurrentStatus ? color.withValues(alpha: 0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _updateRouteStatus(status),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isCurrentStatus ? color : Colors.grey[300]!,
              width: isCurrentStatus ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _getStatusIcon(status),
                color: isCurrentStatus ? color : Colors.grey[600],
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isCurrentStatus ? color : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isCurrentStatus)
                Icon(
                  Icons.check_circle,
                  color: color,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

