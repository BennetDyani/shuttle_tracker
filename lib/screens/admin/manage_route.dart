import 'package:flutter/material.dart';

class ManageRouteScreen extends StatefulWidget {
  const ManageRouteScreen({super.key});

  @override
  State<ManageRouteScreen> createState() => _ManageRouteScreenState();
}

class _ManageRouteScreenState extends State<ManageRouteScreen> {
  final List<Map<String, dynamic>> routes = [
    {
      'id': 'R001',
      'origin': 'Bellville',
      'destination': 'Cape Town Campus',
      'stops': 8,
      'schedules': 4,
    },
    // Add more routes as needed
  ];

  void _showAddRouteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Route'),
        content: const Text('Route creation form goes here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement add route logic
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditRouteDialog(Map<String, dynamic> route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Route: ${route['id']}'),
        content: const Text('Route edit form goes here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement edit route logic
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteRouteDialog(Map<String, dynamic> route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Route'),
        content: Text('Are you sure you want to delete route ${route['id']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement delete route logic
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _manageStops(Map<String, dynamic> route) {
    // TODO: Navigate to manage stops for this route
  }

  void _viewSchedules(Map<String, dynamic> route) {
    // TODO: Navigate to view schedules for this route
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Overview'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Route',
            onPressed: _showAddRouteDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Route'),
                  onPressed: _showAddRouteDialog,
                ),
              ],
            ),
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Route ID')),
                  DataColumn(label: Text('Origin')),
                  DataColumn(label: Text('Destination')),
                  DataColumn(label: Text('Stops')),
                  DataColumn(label: Text('Schedules')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: routes.map((route) {
                  return DataRow(cells: [
                    DataCell(Text(route['id'])),
                    DataCell(Text(route['origin'])),
                    DataCell(Text(route['destination'])),
                    DataCell(Text(route['stops'].toString())),
                    DataCell(Text(route['schedules'].toString())),
                    DataCell(Row(
                      children: [
                        TextButton(
                          onPressed: () => _manageStops(route),
                          child: const Text('Manage Stops'),
                        ),
                        TextButton(
                          onPressed: () => _viewSchedules(route),
                          child: const Text('View Schedules'),
                        ),
                        TextButton(
                          onPressed: () => _showEditRouteDialog(route),
                          child: const Text('Edit'),
                        ),
                        TextButton(
                          onPressed: () => _showDeleteRouteDialog(route),
                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
