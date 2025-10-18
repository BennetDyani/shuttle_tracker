import 'package:flutter/material.dart';

class DriverAssignment {
  final String driver;
  final String shuttle;
  final DateTime startTime;
  final DateTime endTime;

  DriverAssignment({
    required this.driver,
    required this.shuttle,
    required this.startTime,
    required this.endTime,
  });
}

class AssignDriverScreen extends StatefulWidget {
  const AssignDriverScreen({Key? key}) : super(key: key);

  @override
  State<AssignDriverScreen> createState() => _AssignDriverScreenState();
}

class _AssignDriverScreenState extends State<AssignDriverScreen> {
  final List<String> drivers = [
    'Chris Driver',
    'Eve Driver',
    'Frank Driver',
    'Alex Green',
    'John Smith',
  ];
  final List<String> shuttles = [
    'Shuttle S101',
    'Shuttle S102',
    'Shuttle S103',
    'Shuttle S104',
  ];

  String? selectedDriver;
  String? selectedShuttle;
  DateTime? startTime;
  DateTime? endTime;

  final List<DriverAssignment> assignments = [];

  Future<void> _pickStartTime() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          startTime = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
        });
      }
    }
  }

  Future<void> _pickEndTime() async {
    final now = startTime ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      );
      if (time != null) {
        setState(() {
          endTime = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
        });
      }
    }
  }

  void _saveAssignment() {
    if (selectedDriver == null || selectedShuttle == null || startTime == null || endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields.')),
      );
      return;
    }
    if (endTime!.isBefore(startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    setState(() {
      assignments.add(DriverAssignment(
        driver: selectedDriver!,
        shuttle: selectedShuttle!,
        startTime: startTime!,
        endTime: endTime!,
      ));
      selectedDriver = null;
      selectedShuttle = null;
      startTime = null;
      endTime = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Assignment saved!')),
    );
  }

  Widget _buildAssignmentForm() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Assign Driver to Shuttle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedDriver,
              items: drivers.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (val) => setState(() => selectedDriver = val),
              decoration: const InputDecoration(labelText: 'Select Driver'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedShuttle,
              items: shuttles.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => selectedShuttle = val),
              decoration: const InputDecoration(labelText: 'Select Shuttle'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(startTime == null ? 'Start Time: Not set' : 'Start Time: ${startTime!.toLocal().toString().substring(0, 16)}'),
                ),
                TextButton(
                  onPressed: _pickStartTime,
                  child: const Text('Pick Start'),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(endTime == null ? 'End Time: Not set' : 'End Time: ${endTime!.toLocal().toString().substring(0, 16)}'),
                ),
                TextButton(
                  onPressed: _pickEndTime,
                  child: const Text('Pick End'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _saveAssignment,
                child: const Text('Save Assignment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentList() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Current Active Assignments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            assignments.isEmpty
                ? const Text('No active assignments.')
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 500,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: assignments.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final a = assignments[index];
                          return ListTile(
                            leading: const Icon(Icons.assignment_turned_in),
                            title: Text('${a.driver} → ${a.shuttle}'),
                            subtitle: Text('From: ${a.startTime.toLocal().toString().substring(0, 16)}\nTo:   ${a.endTime.toLocal().toString().substring(0, 16)}'),
                          );
                        },
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Assignment Management'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAssignmentForm(),
            const SizedBox(height: 24),
            _buildAssignmentList(),
          ],
        ),
      ),
    );
  }
}
