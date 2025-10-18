import 'package:flutter/material.dart';
import 'live_tracking_screen.dart';

class StopsScreen extends StatefulWidget {
  const StopsScreen({super.key});

  @override
  State<StopsScreen> createState() => _StopsScreenState();
}

class _StopsScreenState extends State<StopsScreen> {
  String _selectedRoute = 'Route A – Main Campus Loop';

  final List<String> _routes = [
    'Route A – Main Campus Loop',
    'Route B – Science Park',
    'Route C – Residences',
  ];

  final Map<String, List<Map<String, String>>> _stopsPerRoute = {
    'Route A – Main Campus Loop': [
      {'name': 'North Gate', 'eta': '7 min'},
      {'name': 'Library', 'eta': '12 min'},
      {'name': 'South Gate', 'eta': '18 min'},
    ],
    'Route B – Science Park': [
      {'name': 'Library', 'eta': '5 min'},
      {'name': 'Science Park', 'eta': '10 min'},
    ],
    'Route C – Residences': [
      {'name': 'Main Hall', 'eta': '6 min'},
      {'name': 'Residences', 'eta': '14 min'},
    ],
  };

  @override
  Widget build(BuildContext context) {
    final stops = _stopsPerRoute[_selectedRoute] ?? [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stops'),
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedRoute,
              items: _routes.map((route) => DropdownMenuItem(
                value: route,
                child: Text(route),
              )).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedRoute = val);
              },
              decoration: const InputDecoration(
                labelText: 'Select Route',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: stops.length,
                itemBuilder: (context, index) {
                  final stop = stops[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(stop['name']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 16, color: Colors.blueGrey),
                                  const SizedBox(width: 4),
                                  Text('Next shuttle: ${stop['eta']}'),
                                ],
                              ),
                            ],
                          ),
                          ElevatedButton(
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
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
