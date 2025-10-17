import 'package:flutter/material.dart';

class DriverSettingsPage extends StatefulWidget {
  const DriverSettingsPage({super.key});

  @override
  State<DriverSettingsPage> createState() => _DriverSettingsPageState();
}

class _DriverSettingsPageState extends State<DriverSettingsPage> {
  bool _gpsTracking = true;
  bool _darkMode = false;
  bool _shiftReminders = true;

  void _clearCache() {
    // TODO: Implement cache clearing logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache cleared and settings reset.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              value: _gpsTracking,
              onChanged: (val) => setState(() => _gpsTracking = val),
              title: const Text('Enable GPS Tracking'),
              secondary: const Icon(Icons.gps_fixed),
            ),
            SwitchListTile(
              value: _darkMode,
              onChanged: (val) => setState(() => _darkMode = val),
              title: const Text('Dark Mode'),
              secondary: const Icon(Icons.dark_mode),
            ),
            SwitchListTile(
              value: _shiftReminders,
              onChanged: (val) => setState(() => _shiftReminders = val),
              title: const Text('Shift Reminders'),
              secondary: const Icon(Icons.notifications_active),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _clearCache,
              icon: const Icon(Icons.refresh),
              label: const Text('Clear Cache / Reset'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
