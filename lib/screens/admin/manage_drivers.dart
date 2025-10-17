import 'package:flutter/material.dart';

class ManageDriversScreen extends StatefulWidget {
  const ManageDriversScreen({super.key});

  @override
  State<ManageDriversScreen> createState() => _ManageDriversScreenState();
}

class _ManageDriversScreenState extends State<ManageDriversScreen> {
  final List<Map<String, String>> drivers = [
    {
      'id': '001',
      'name': 'Sipho Mthembu',
      'license': 'L29392',
      'shuttle': 'Shuttle #12',
      'status': 'Active',
    },
    // Add more drivers as needed
  ];

  final List<String> availableShuttles = [
    'Shuttle #12',
    'Shuttle #15',
    'Shuttle #20',
  ];

  void _showAddDriverDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Driver'),
          content: const Text('Driver creation form goes here.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement add driver logic
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditDriverDialog(Map<String, String> driver) {
    showDialog(
      context: context,
      builder: (context) {
        String selectedShuttle = driver['shuttle'] ?? availableShuttles.first;
        return AlertDialog(
          title: Text('Edit Driver: ${driver['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedShuttle,
                items: availableShuttles.map((shuttle) => DropdownMenuItem(
                  value: shuttle,
                  child: Text(shuttle),
                )).toList(),
                onChanged: (val) {
                  if (val != null) selectedShuttle = val;
                },
                decoration: const InputDecoration(labelText: 'Assigned Shuttle'),
              ),
              // Add more editable fields as needed
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement update logic
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showRemoveDriverDialog(Map<String, String> driver) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Driver'),
          content: Text('Are you sure you want to remove ${driver['name']}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement remove logic
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  void _viewAssignments(Map<String, String> driver) {
    // TODO: Navigate to DriverAssignment list for this driver
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Management'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add New Driver',
            onPressed: _showAddDriverDialog,
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
                  label: const Text('Add New Driver'),
                  onPressed: _showAddDriverDialog,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.assignment),
                  label: const Text('View Assignments'),
                  onPressed: () {
                    // TODO: Navigate to assignments list
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Driver ID')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('License')),
                  DataColumn(label: Text('Assigned Shuttle')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: drivers.map((driver) {
                  return DataRow(cells: [
                    DataCell(Text(driver['id'] ?? '')),
                    DataCell(Text(driver['name'] ?? '')),
                    DataCell(Text(driver['license'] ?? '')),
                    DataCell(
                      DropdownButton<String>(
                        value: driver['shuttle'],
                        items: availableShuttles.map((shuttle) => DropdownMenuItem(
                          value: shuttle,
                          child: Text(shuttle),
                        )).toList(),
                        onChanged: (val) {
                          // TODO: Update shuttle assignment
                        },
                      ),
                    ),
                    DataCell(Text(driver['status'] ?? '')),
                    DataCell(Row(
                      children: [
                        TextButton(
                          onPressed: () => _showEditDriverDialog(driver),
                          child: const Text('Edit'),
                        ),
                        TextButton(
                          onPressed: () => _viewAssignments(driver),
                          child: const Text('View'),
                        ),
                        TextButton(
                          onPressed: () => _showRemoveDriverDialog(driver),
                          child: const Text('Remove', style: TextStyle(color: Colors.red)),
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
