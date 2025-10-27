import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/APIService.dart';
import '../../providers/auth_provider.dart';
import '../../models/User.dart';
import 'student_live_tracking_screen.dart';

/// Unified schedule screen for all students.
/// Shows all shuttle schedules with plate numbers.
/// Disabled students see only minibus schedules, normal students see bus schedules.
class StudentScheduleScreen extends StatefulWidget {
  const StudentScheduleScreen({super.key});

  @override
  State<StudentScheduleScreen> createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> {
  final APIService _apiService = APIService();

  bool _isLoadingUser = true;
  bool _isDisabledStudent = false;
  bool _isLoadingSchedules = true;
  String? _errorMessage;

  List<dynamic> _schedules = [];
  final Map<String, dynamic> _shuttleMap = {};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadUserInfo();
    await _loadShuttles();
    await _loadSchedules();
  }

  Future<void> _loadUserInfo() async {
    setState(() => _isLoadingUser = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uidStr = auth.userId;
      if (uidStr != null && uidStr.isNotEmpty) {
        final uid = int.parse(uidStr);
        final userMap = await _apiService.fetchUserById(uid);
        final user = User.fromJson(userMap);
        setState(() => _isDisabledStudent = user.disability);
      }
    } catch (e) {
      debugPrint('Error loading user info: $e');
    } finally {
      setState(() => _isLoadingUser = false);
    }
  }

  Future<void> _loadShuttles() async {
    try {
      final shuttles = await _apiService.fetchShuttles();
      // Load all shuttles regardless of type
      setState(() {
        for (var shuttle in shuttles) {
          final id = shuttle['shuttleId']?.toString() ?? shuttle['shuttle_id']?.toString();
          if (id != null) _shuttleMap[id] = shuttle;
        }
      });
    } catch (e) {
      debugPrint('Error loading shuttles: $e');
    }
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _isLoadingSchedules = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uidStr = auth.userId;
      final int? uid = uidStr != null && uidStr.isNotEmpty ? int.tryParse(uidStr) : null;

      final results = await _apiService.fetchSchedules(
        userId: uid,
        page: 1,
        pageSize: 50,
      );

      // Show all schedules regardless of shuttle type
      setState(() {
        _schedules = results;
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoadingSchedules = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return Scaffold(
        appBar: AppBar(title: const Text('Schedules')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Schedules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initialize,
          ),
        ],
      ),
      body: _isLoadingSchedules
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _schedules.isEmpty
                  ? _buildEmptyView()
                  : _buildSchedulesList(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _initialize,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_bus, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No schedules available'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _initialize,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _schedules.length,
      itemBuilder: (context, index) => _buildScheduleCard(_schedules[index]),
    );
  }

  Widget _buildScheduleCard(dynamic schedule) {
    final shuttleId = schedule['shuttleId']?.toString() ?? schedule['shuttle_id']?.toString();
    final shuttle = shuttleId != null ? _shuttleMap[shuttleId] : null;
    final plateNumber = shuttle?['licensePlate']?.toString() ?? shuttle?['plate']?.toString() ?? 'Unknown';
    final shuttleType = shuttle?['shuttleType']?.toString() ?? shuttle?['type']?.toString() ?? 'Unknown';
    final capacity = shuttle?['capacity']?.toString() ?? 'N/A';
    final routeName = schedule['routeName']?.toString() ?? schedule['route']?.toString() ?? 'Unknown Route';
    final departureTime = schedule['departureTime']?.toString() ?? schedule['start']?.toString() ?? 'N/A';
    final arrivalTime = schedule['arrivalTime']?.toString() ?? schedule['end']?.toString() ?? 'N/A';
    final day = schedule['day']?.toString() ?? 'Daily';
    final status = schedule['status']?.toString() ?? 'scheduled';
    final origin = schedule['origin']?.toString() ?? 'Start';
    final destination = schedule['destination']?.toString() ?? 'End';

    // Determine icon based on shuttle type
    final IconData shuttleIcon = shuttleType.toUpperCase() == 'MINIBUS'
        ? Icons.accessible
        : Icons.directions_bus;
    final Color shuttleColor = shuttleType.toUpperCase() == 'MINIBUS'
        ? Colors.blue
        : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: shuttleColor,
          child: Icon(shuttleIcon, color: Colors.white),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plateNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: shuttleType.toUpperCase() == 'MINIBUS' ? Colors.blue.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    shuttleType.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: shuttleType.toUpperCase() == 'MINIBUS' ? Colors.blue.shade900 : Colors.green.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(routeName, style: const TextStyle(fontSize: 14, color: Colors.blue)),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(departureTime, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: status.toLowerCase() == 'active' ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                // Shuttle Details Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Shuttle Details',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(Icons.directions_bus, 'Type', shuttleType),
                      const SizedBox(height: 6),
                      _buildDetailRow(Icons.people, 'Capacity', capacity),
                      const SizedBox(height: 6),
                      _buildDetailRow(Icons.credit_card, 'Plate Number', plateNumber),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Route Details Section
                _buildDetailRow(Icons.location_on, 'Origin', origin),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.flag, 'Destination', destination),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.schedule, 'Departure', departureTime),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.schedule_outlined, 'Arrival', arrivalTime),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.calendar_today, 'Day', day),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to live tracking
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StudentLiveTrackingScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.location_searching, size: 18),
                      label: const Text('Track'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        _showScheduleDetails(schedule, shuttle);
                      },
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('More Info'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  void _showScheduleDetails(dynamic schedule, dynamic shuttle) {
    final shuttleType = shuttle?['shuttleType']?.toString() ?? shuttle?['type']?.toString() ?? 'Unknown';
    final icon = shuttleType.toUpperCase() == 'MINIBUS' ? Icons.accessible : Icons.directions_bus;
    final color = shuttleType.toUpperCase() == 'MINIBUS' ? Colors.blue : Colors.green;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            const Expanded(child: Text('Complete Schedule Details')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Shuttle Information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: color, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Shuttle Information',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildDialogDetail('Plate Number', shuttle?['licensePlate']?.toString() ?? 'N/A'),
                    _buildDialogDetail('Type', shuttleType),
                    _buildDialogDetail('Capacity', shuttle?['capacity']?.toString() ?? 'N/A'),
                    _buildDialogDetail('Status', shuttle?['status']?.toString() ?? 'Active'),
                    _buildDialogDetail('Driver', shuttle?['driverName']?.toString() ?? 'Assigned'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Route Information
              const Text(
                'Route Information',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Divider(height: 16),
              _buildDialogDetail('Route', schedule['routeName']?.toString() ?? 'N/A'),
              _buildDialogDetail('Origin', schedule['origin']?.toString() ?? 'N/A'),
              _buildDialogDetail('Destination', schedule['destination']?.toString() ?? 'N/A'),
              const SizedBox(height: 16),
              // Schedule Information
              const Text(
                'Schedule Information',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Divider(height: 16),
              _buildDialogDetail('Departure', schedule['departureTime']?.toString() ?? 'N/A'),
              _buildDialogDetail('Arrival', schedule['arrivalTime']?.toString() ?? 'N/A'),
              _buildDialogDetail('Day', schedule['day']?.toString() ?? 'Daily'),
              _buildDialogDetail('Status', schedule['status']?.toString() ?? 'Scheduled'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StudentLiveTrackingScreen()),
              );
            },
            icon: const Icon(Icons.location_on),
            label: const Text('Track Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

