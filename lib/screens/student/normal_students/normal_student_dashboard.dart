import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/APIService.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/notifications_provider.dart';
import 'route_screen.dart';
import 'stop_screen.dart';
import 'profile_page.dart';
import 'complaints_screen.dart';
import 'live_tracking_screen.dart';
import 'schedule_screen.dart';
import 'notifications_screen.dart';

class NormalStudentDashboard extends StatefulWidget {
  const NormalStudentDashboard({super.key});

  @override
  State<NormalStudentDashboard> createState() => _NormalStudentDashboardState();
}

class _NormalStudentDashboardState extends State<NormalStudentDashboard> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    DashboardHomeScreen(),
    RoutesScreen(),
    StopsScreen(),
    ProfilePage(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus_filled_outlined),
            label: "Routes",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on_outlined),
            label: "Stops",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
        onTap: _onTabTapped,
      ),
    );
  }
}

class DashboardHomeScreen extends StatefulWidget {
  DashboardHomeScreen({Key? key}) : super(key: key);

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
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
    final titleText = _isLoadingName ? 'Hi' : (_displayName.isNotEmpty ? 'Hi, $_displayName 👋' : 'Hi');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: Text(
          titleText,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          Consumer<NotificationsProvider>(builder: (context, notif, _) {
            return IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none, color: Colors.black),
                  if (notif.isLoading)
                    const Positioned(
                      right: -6,
                      top: -6,
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  if (!notif.isLoading && notif.unreadCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Center(
                          child: Text(
                            notif.unreadCount > 99 ? '99+' : notif.unreadCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () async {
                // Optionally refresh notification count before opening
                try {
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  final uidStr = auth.userId;
                  final int? uid = uidStr != null && uidStr.isNotEmpty ? int.tryParse(uidStr) : null;
                  await Provider.of<NotificationsProvider>(context, listen: false).refresh(userId: uid);
                } catch (_) {}
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
            );
          }),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) _buildErrorBanner(),
            _buildNextShuttleCard(context),
            const SizedBox(height: 20),
            _buildMapCard(),
            const SizedBox(height: 20),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      color: Colors.red[100],
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: Colors.red[800]),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.red[800]),
            onPressed: () {
              setState(() {
                _error = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNextShuttleCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: shuttle info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Next Shuttle", style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.directions_bus, color: Colors.blue, size: 26),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text("Campus Loop A", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text("Arriving in 5 mins", style: TextStyle(color: Colors.green, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Right: call-to-action button
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LiveTrackingScreen()),
                );
              },
              icon: const Icon(Icons.location_searching, size: 18),
              label: const Text('Track Shuttle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 180,
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
              ),
              width: double.infinity,
              height: double.infinity,
              child: const Center(
                child: Text(
                  "[Mini Map Placeholder]",
                  style: TextStyle(color: Colors.blueGrey, fontSize: 16),
                ),
              ),
            ),
            Positioned(
              left: 30,
              top: 40,
              child: GestureDetector(
                onTap: () {},
                child: const Icon(Icons.location_on, color: Colors.red, size: 32),
              ),
            ),
            Positioned(
              right: 40,
              bottom: 30,
              child: GestureDetector(
                onTap: () {},
                child: const Icon(Icons.location_on, color: Colors.green, size: 32),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildActionButton(context, Icons.directions_bus, "View Stops", () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StopsScreen()),
          );
        }),
        _buildActionButton(context, Icons.schedule, "View Schedule", () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StudentScheduleScreen()),
          );
        }),
        _buildActionButton(context, Icons.campaign_outlined, "Complaints/Feedback", () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ComplaintsScreen()),
          );
        }),
        _buildActionButton(context, Icons.person, "Profile", () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfilePage()),
          );
        }),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey[200],
            child: Icon(icon, size: 28, color: Colors.black54),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
