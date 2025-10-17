import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shuttle_tracker/providers/auth_provider.dart';

class DisabledStudentProfilePage extends StatefulWidget {
  const DisabledStudentProfilePage({super.key});

  @override
  State<DisabledStudentProfilePage> createState() => _DisabledStudentProfilePageState();
}

class _DisabledStudentProfilePageState extends State<DisabledStudentProfilePage> {
  bool _voiceAssistance = false;
  bool _highContrast = false;
  bool _vibrationFeedback = false;

  // Example student data; replace with real data source
  final student = const {
    'name': 'Mphathi Dlamini',
    'id': '20251234',
    'email': 'mphathi.dlamini@university.edu',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Accessibility'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.blue[100],
                          child: const Icon(Icons.person, size: 40, color: Colors.blueGrey),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(student['name']!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Student ID: ${student['id']}', style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(student['email']!, style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SwitchListTile(
              value: _voiceAssistance,
              onChanged: (val) => setState(() => _voiceAssistance = val),
              title: const Text('Voice Assistance'),
              secondary: const Icon(Icons.record_voice_over),
            ),
            SwitchListTile(
              value: _highContrast,
              onChanged: (val) => setState(() => _highContrast = val),
              title: const Text('High Contrast Mode'),
              secondary: const Icon(Icons.contrast),
            ),
            SwitchListTile(
              value: _vibrationFeedback,
              onChanged: (val) => setState(() => _vibrationFeedback = val),
              title: const Text('Vibration Feedback'),
              secondary: const Icon(Icons.vibration),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement edit personal info
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit Personal Info'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                authProvider.logout();
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
