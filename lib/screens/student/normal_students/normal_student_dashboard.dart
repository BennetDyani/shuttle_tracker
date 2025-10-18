import 'package:flutter/material.dart';
import 'route_screen.dart';
import 'stop_screen.dart';
import 'profile_page.dart';
import 'complaints_screen.dart';
import 'live_tracking_screen.dart';

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

class DashboardHomeScreen extends StatelessWidget {
  DashboardHomeScreen({Key? key}) : super(key: key);

  static BuildContext? _dashboardContext;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: const Text(
          "Hi, Mphathi 👋",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

  Widget _buildNextShuttleCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Next Shuttle", style: TextStyle(fontSize: 16, color: Colors.grey)),
                SizedBox(height: 4),
                Text("Campus Loop A", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text("Arriving in 5 mins", style: TextStyle(color: Colors.green, fontSize: 16)),
              ],
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LiveTrackingScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Track Shuttle"),
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
    _dashboardContext = context;
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
            MaterialPageRoute(builder: (_) => const RoutesScreen()),
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
