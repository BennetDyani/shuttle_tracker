import 'package:flutter/material.dart';
// For a real map, use a package like google_maps_flutter or flutter_map.
// This is a placeholder UI for demonstration.

class LiveTrackingScreen extends StatelessWidget {
  const LiveTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Shuttle'),
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: Stack(
        children: [
          // Map placeholder
          Container(
            color: Colors.blue[50],
            width: double.infinity,
            height: double.infinity,
            child: const Center(
              child: Text('[MapView Placeholder]', style: TextStyle(color: Colors.blueGrey, fontSize: 18)),
            ),
          ),
          // Example shuttle marker
          Positioned(
            left: 120,
            top: 200,
            child: Column(
              children: const [
                Icon(Icons.directions_bus, color: Colors.blue, size: 40),
                Text('Shuttle', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // Example student marker (optional)
          Positioned(
            right: 80,
            bottom: 180,
            child: Column(
              children: const [
                Icon(Icons.person_pin_circle, color: Colors.green, size: 36),
                Text('You', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          // Legend
          Positioned(
            top: 20,
            right: 20,
            child: Card(
              color: Colors.white,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.directions_bus, color: Colors.blue, size: 20),
                    SizedBox(width: 4),
                    Text('Shuttle', style: TextStyle(fontSize: 12)),
                    SizedBox(width: 12),
                    Icon(Icons.location_on, color: Colors.red, size: 20),
                    SizedBox(width: 4),
                    Text('Stop', style: TextStyle(fontSize: 12)),
                    SizedBox(width: 12),
                    Icon(Icons.person_pin_circle, color: Colors.green, size: 20),
                    SizedBox(width: 4),
                    Text('You', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Campus Loop A', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: const [
                Icon(Icons.access_time, size: 18, color: Colors.blueGrey),
                SizedBox(width: 6),
                Text('ETA to your stop: 5 mins', style: TextStyle(fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Implement notification logic
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Set Notification When Near'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
