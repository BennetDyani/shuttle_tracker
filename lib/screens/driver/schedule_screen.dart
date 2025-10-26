import 'package:flutter/material.dart';
import '../../services/APIService.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _schedules = [];

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await APIService().fetchSchedules();
      if (!mounted) return;

      setState(() {
        _schedules = result.map((s) => s as Map<String, dynamic>).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSchedules,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 600;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Error: $_error',
                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadSchedules,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _schedules.isEmpty
                          ? const Center(child: Text('No schedules found'))
                          : SingleChildScrollView(
                              padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: isSmallScreen
                                          ? _buildSchedulesList()
                                          : _buildSchedulesTable(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSchedulesList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _schedules.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final schedule = _schedules[index];
        return ListTile(
          title: Text(schedule['route_name'] ?? 'Unknown Route'),
          subtitle: Text(
            'Time: ${schedule['start_time'] ?? 'N/A'} - ${schedule['end_time'] ?? 'N/A'}\n'
            'Days: ${schedule['days'] ?? 'Not specified'}',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showScheduleDetails(schedule),
          ),
        );
      },
    );
  }

  Widget _buildSchedulesTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Route')),
          DataColumn(label: Text('Start Time')),
          DataColumn(label: Text('End Time')),
          DataColumn(label: Text('Days')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _schedules.map((schedule) {
          return DataRow(
            cells: [
              DataCell(Text(schedule['route_name'] ?? 'Unknown Route')),
              DataCell(Text(schedule['start_time'] ?? 'N/A')),
              DataCell(Text(schedule['end_time'] ?? 'N/A')),
              DataCell(Text(schedule['days'] ?? 'Not specified')),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => _showScheduleDetails(schedule),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showScheduleDetails(Map<String, dynamic> schedule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(schedule['route_name'] ?? 'Schedule Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Route', schedule['route_name']),
              _detailRow('Start Time', schedule['start_time']),
              _detailRow('End Time', schedule['end_time']),
              _detailRow('Days', schedule['days']),
              _detailRow('Stops', schedule['stops']?.join(', ')),
              if (schedule['notes'] != null) _detailRow('Notes', schedule['notes']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(value ?? 'Not specified'),
        ],
      ),
    );
  }
}
