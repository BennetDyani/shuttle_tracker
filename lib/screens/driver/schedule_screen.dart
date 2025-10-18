import 'package:flutter/material.dart';
import '../../services/APIService.dart';
import '../../services/endpoints.dart';

class DriverScheduleScreen extends StatefulWidget {
  const DriverScheduleScreen({super.key});

  @override
  State<DriverScheduleScreen> createState() => _DriverScheduleScreenState();
}

class _DriverScheduleScreenState extends State<DriverScheduleScreen> {
  List<dynamic> assignments = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSchedule();
  }

  Future<void> _fetchSchedule() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      // Replace with actual driver ID
      final scheduleData = await APIService().get(Endpoints.scheduleReadByDriverId(1));
      setState(() {
        assignments = scheduleData;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

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
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
