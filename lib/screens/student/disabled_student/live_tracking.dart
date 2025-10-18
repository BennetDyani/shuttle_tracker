import 'package:flutter/material.dart';

class DisabledLiveTrackingScreen extends StatelessWidget {
  const DisabledLiveTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // High-contrast map placeholder
          Container(
            color: Colors.black,
            width: double.infinity,
            height: double.infinity,
            child: const Center(
              child: Text('[High-Contrast MapView Placeholder]', style: TextStyle(color: Colors.yellow, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
          // Large shuttle marker
          Positioned(
            left: 120,
            top: 200,
            child: Column(
              children: const [
                Icon(Icons.directions_bus, color: Colors.yellow, size: 64),
                Text('Shuttle', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
              ],
            ),
          ),
          // Optional Read ETA Aloud button
          Positioned(
            top: 40,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement TTS for ETA
              },
              icon: const Icon(Icons.volume_up, color: Colors.black),
              label: const Text('Read ETA Aloud', style: TextStyle(color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
            ),
          ),
          // Bottom card with info and assistance button
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 12,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Route: Campus Loop A', style: TextStyle(color: Colors.yellow, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      Icon(Icons.access_time, color: Colors.yellow, size: 22),
                      SizedBox(width: 8),
                      Text('ETA: 5 mins', style: TextStyle(color: Colors.white, fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      Icon(Icons.person, color: Colors.yellow, size: 22),
                      SizedBox(width: 8),
                      Text('Driver: Mr. Ndlovu', style: TextStyle(color: Colors.white, fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement call for assistance
                      },
                      icon: const Icon(Icons.support_agent, color: Colors.black),
                      label: const Text('Call for Assistance', style: TextStyle(color: Colors.black)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

