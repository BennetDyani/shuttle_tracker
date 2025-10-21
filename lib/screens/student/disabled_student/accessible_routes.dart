import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';

class AccessibleRoutesScreen extends StatelessWidget {
  const AccessibleRoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Example accessible routes data
    final accessibleRoutes = [
      {
        'route': 'Route A – Main Campus Loop',
        'accessible': true,
        'stop': 'North Gate',
        'eta': '5 min',
      },
      {
        'route': 'Route B – Science Park',
        'accessible': true,
        'stop': 'Science Park',
        'eta': '8 min',
      },
      {
        'route': 'Route C – Residences',
        'accessible': true,
        'stop': 'Residences',
        'eta': '12 min',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accessible Routes'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              final role = context.read<AuthProvider>().role?.toUpperCase();
              final route = (role == 'DISABLED_STUDENT') ? '/student/disabled/dashboard' : '/student/dashboard';
              Navigator.pushReplacementNamed(context, route);
            },
            child: const Text('Dashboard', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: accessibleRoutes.length,
        itemBuilder: (context, index) {
          final route = accessibleRoutes[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        route['route'] as String,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      if (route['accessible'] == true)
                        const Icon(Icons.accessible, color: Colors.blue, size: 22),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.green, size: 18),
                      const SizedBox(width: 4),
                      Text(route['stop'] as String),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.blueGrey),
                      const SizedBox(width: 4),
                      Text('ETA: ${route['eta']}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Implement view on map
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('View on Map'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
