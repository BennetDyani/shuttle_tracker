import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/APIService.dart';
import '../../services/shuttle_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final ShuttleService _shuttleService = ShuttleService();
  bool isLoading = true;
  String? errorMessage;

  Map<String, dynamic>? driverAssignment;
  Map<String, dynamic>? scheduleDetails;
  Map<String, dynamic>? routeDetails;
  int? driverId;

  @override
  void initState() {
    super.initState();
    _loadDriverSchedule();
  }

  Future<void> _loadDriverSchedule() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // 1. Get current user's driver ID
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

      // 2. Get driver record
      final fetchedDriver = await APIService().fetchDriverByEmail(email);
      driverId = fetchedDriver['driver_id'] ?? fetchedDriver['driverId'] ?? fetchedDriver['id'];

      if (driverId == null) {
        throw Exception('Driver ID not found');
      }

      // 3. Get driver's assignment
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
          errorMessage = 'No schedule assigned to you yet. Please contact the administrator.';
        });
        return;
      }

      driverAssignment = matched;

      // 4. Get schedule details
      final scheduleId = (matched['scheduleId'] ?? matched['schedule_id'] ?? matched['schedule'])?.toString();
      if (scheduleId != null && scheduleId.isNotEmpty) {
        final schedules = await _shuttleService.getSchedules();
        for (final s in schedules) {
          final sid = (s['schedule_id'] ?? s['scheduleId'] ?? s['id'])?.toString();
          if (sid == scheduleId) {
            scheduleDetails = s;
            break;
          }
        }

        // 5. Get route details if schedule has a route
        if (scheduleDetails != null) {
          final routeId = (scheduleDetails!['route_id'] ?? scheduleDetails!['routeId'] ?? scheduleDetails!['route'])?.toString();
          if (routeId != null && routeId.isNotEmpty) {
            final routes = await _shuttleService.getRoutes();
            for (final r in routes) {
              final rid = (r['route_id'] ?? r['routeId'] ?? r['id'])?.toString();
              if (rid == routeId) {
                routeDetails = r;
                break;
              }
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

  String _formatTime(String? time) {
    if (time == null || time.trim().isEmpty) return 'Not set';
    try {
      // Try parsing as HH:mm first
      final parsed = DateFormat.Hm().parseLoose(time);
      return DateFormat.Hm().format(parsed);
    } catch (_) {
      try {
        // Fallback to ISO DateTime.parse (handles full timestamps)
        final dt = DateTime.parse(time);
        return DateFormat.Hm().format(dt);
      } catch (_) {
        return time;
      }
    }
  }

  String _getDayOfWeek() {
    if (scheduleDetails == null) return 'Not set';
    return (scheduleDetails!['day_of_week'] ??
            scheduleDetails!['dayOfWeek'] ??
            scheduleDetails!['day'] ??
            'Not set').toString();
  }

  String _getRouteName() {
    if (routeDetails != null) {
      return (routeDetails!['name'] ??
              routeDetails!['routeName'] ??
              routeDetails!['route_name'] ??
              'Unknown Route').toString();
    }
    if (scheduleDetails != null) {
      return (scheduleDetails!['route_name'] ??
              scheduleDetails!['routeName'] ??
              'Unknown Route').toString();
    }
    if (driverAssignment != null) {
      return (driverAssignment!['route_name'] ??
              driverAssignment!['routeName'] ??
              'Unknown Route').toString();
    }
    return 'Unknown Route';
  }

  String _getRouteDescription() {
    if (routeDetails != null) {
      return (routeDetails!['description'] ??
              routeDetails!['route_description'] ??
              'No description available').toString();
    }
    return 'No description available';
  }

  String _getDepartureTime() {
    if (scheduleDetails == null) return 'Not set';
    final time = scheduleDetails!['departure_time'] ??
                 scheduleDetails!['departureTime'] ??
                 scheduleDetails!['start_time'] ??
                 scheduleDetails!['start'];
    return _formatTime(time?.toString());
  }

  String _getArrivalTime() {
    if (scheduleDetails == null) return 'Not set';
    final time = scheduleDetails!['arrival_time'] ??
                 scheduleDetails!['arrivalTime'] ??
                 scheduleDetails!['end_time'] ??
                 scheduleDetails!['end'];
    return _formatTime(time?.toString());
  }

  String _getAssignmentDate() {
    if (driverAssignment == null) return 'Not set';
    final date = driverAssignment!['assignment_date'] ??
                 driverAssignment!['assignmentDate'] ??
                 driverAssignment!['date'];
    if (date == null) return 'Not set';
    try {
      final dt = DateTime.parse(date.toString());
      return DateFormat('MMM dd, yyyy').format(dt);
    } catch (_) {
      return date.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        elevation: 0,
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
                          Icons.schedule_outlined,
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
                          onPressed: _loadDriverSchedule,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDriverSchedule,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Route Information Card
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
                                        'Route Information',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                _buildInfoRow('Route Name', _getRouteName(), Icons.map),
                                const SizedBox(height: 12),
                                _buildInfoRow('Description', _getRouteDescription(), Icons.info_outline),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Schedule Times Card
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
                                      Icons.access_time,
                                      color: Theme.of(context).primaryColor,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Schedule Times',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                _buildInfoRow('Day of Week', _getDayOfWeek(), Icons.calendar_today),
                                const SizedBox(height: 12),
                                _buildInfoRow('Departure Time', _getDepartureTime(), Icons.flight_takeoff),
                                const SizedBox(height: 12),
                                _buildInfoRow('Arrival Time', _getArrivalTime(), Icons.flight_land),
                                const SizedBox(height: 12),
                                _buildInfoRow('Assignment Date', _getAssignmentDate(), Icons.event),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Quick Actions Card
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quick Actions',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        icon: const Icon(Icons.arrow_back),
                                        label: const Text('Back to Dashboard'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Info message
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Pull down to refresh your schedule',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

