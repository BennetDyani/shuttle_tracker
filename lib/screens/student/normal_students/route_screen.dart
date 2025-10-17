import 'package:flutter/material.dart';
import 'live_tracking_screen.dart';

class RoutesScreen extends StatelessWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Example data; replace with real data source
    final routes = [
      {
        'name': 'Route A – Main Campus Loop',
        'start': 'North Gate',
        'end': 'South Gate',
        'hours': '06:00 – 22:00',
      },
      {
        'name': 'Route B – Science Park',
        'start': 'Library',
        'end': 'Science Park',
        'hours': '07:00 – 20:00',
      },
      {
        'name': 'Route C – Residences',
        'start': 'Main Hall',
        'end': 'Residences',
        'hours': '06:30 – 21:30',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shuttle Routes'),
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: routes.length,
        itemBuilder: (context, index) {
          final route = routes[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route['name']!,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.play_arrow, size: 18, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(route['start']!),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 16),
                      const SizedBox(width: 8),
                      const Icon(Icons.flag, size: 18, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(route['end']!),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.blueGrey),
                      const SizedBox(width: 4),
                      Text('Operating hours: ${route['hours']}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LiveTrackingScreen()),
                        );
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
