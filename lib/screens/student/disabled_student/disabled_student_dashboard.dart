import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/APIService.dart';
import '../../../providers/auth_provider.dart';
import 'accessible_routes.dart';
import 'profile_page.dart';
import 'report_issues.dart';
import 'live_tracking.dart';

class DisabledStudentDashboard extends StatefulWidget {
  const DisabledStudentDashboard({super.key});

  @override
  State<DisabledStudentDashboard> createState() => _DisabledStudentDashboardState();
}

class _DisabledStudentDashboardState extends State<DisabledStudentDashboard> {
  bool _isLoadingName = true;
  String _displayName = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    setState(() {
      _isLoadingName = true;
      _error = null;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uidStr = auth.userId;
      if (uidStr == null || uidStr.isEmpty) throw Exception('Not logged in');
      final uid = int.tryParse(uidStr);
      if (uid == null) throw Exception('Invalid user id');
      final user = await APIService().fetchUserById(uid);
      final first = (user['first_name'] ?? user['name'] ?? '').toString();
      final last = (user['last_name'] ?? user['surname'] ?? '').toString();
      final combined = ('$first $last').trim();
      setState(() {
        _displayName = combined.isEmpty ? (user['email'] ?? '') as String? ?? '' : combined;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingName = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isLoadingName ? 'Welcome' : (_displayName.isNotEmpty ? 'Hi, $_displayName' : 'Welcome');
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic, size: 28),
            onPressed: () {
              // TODO: Implement voice navigation
            },
            tooltip: 'Voice Navigation',
          ),
        ],
        backgroundColor: Colors.blue[800],
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // My Shuttle Card
            Card(
              color: Colors.blue[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.directions_bus, size: 36, color: Colors.blue),
                        SizedBox(width: 12),
                        Text('My Shuttle (Minibus Required)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('Assigned Route: Accessible Route A', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 6),
                    Row(
                      children: const [
                        Icon(Icons.access_time, size: 18, color: Colors.green),
                        SizedBox(width: 6),
                        Text('On route — 3 mins away', style: TextStyle(color: Colors.green, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const DisabledLiveTrackingScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Track My Shuttle'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // View Schedule
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AccessibleRoutesScreen()),
                  );
                },
                icon: const Icon(Icons.calendar_today, size: 28),
                label: const Text('View Schedule', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Accessible Stops
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AccessibleRoutesScreen()),
                  );
                },
                icon: const Icon(Icons.location_on, size: 28),
                label: const Text('Accessible Stops', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Report an Issue
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ReportIssueScreen()),
                  );
                },
                icon: const Icon(Icons.campaign, size: 28),
                label: const Text('Report an Issue', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Profile & Accessibility Settings
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DisabledStudentProfilePage()),
                  );
                },
                icon: const Icon(Icons.person, size: 28),
                label: const Text('Profile & Accessibility Settings', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
      // Bottom Voice Bar
      bottomNavigationBar: Container(
        color: Colors.blue[900],
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.mic, color: Colors.blue, size: 28),
                onPressed: () {
                  // TODO: Implement voice command
                },
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                "Say 'Track my shuttle' or 'View stops'",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
