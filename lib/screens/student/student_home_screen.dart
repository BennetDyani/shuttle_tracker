import 'package:flutter/material.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leadingWidth: 120,
        leading: Row(
          children: [
            const SizedBox(width: 8),
            const CircleAvatar(
              // In a real app, use AssetImage or NetworkImage
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text(
              "John D.",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {
              // Handle notifications tap
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Next Shuttle"),
            _buildNextShuttleCard(),
            const SizedBox(height: 24),
            _buildQuickActionButtons(),
            const SizedBox(height: 24),
            _buildSectionTitle("Nearby Shuttles"),
            _buildNearbyShuttleCard("Route 2B", "2KM away", "8 min"),
            const SizedBox(height: 8),
            _buildNearbyShuttleCard("Route 3C", "3.5KM away", "12 min"),
            const SizedBox(height: 24),
            _buildSectionTitle("Recent Routes"),
            _buildRecentRouteCard("Bellville Campus → District 6 Campus", "Today, 9:30 AM"),
            const SizedBox(height: 8),
            _buildRecentRouteCard("Cape Town Campus → Granger Bay Campus", "Yesterday, 4:15 PM"),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Ensures all items are visible
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        currentIndex: 0, // Highlights the Home icon
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus_filled_outlined), // Changed from road
            label: "Routes",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: "Alerts",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
        onTap: (index) {
          // Handle bottom navigation tap
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildNextShuttleCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Arriving in", style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text("5 min", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text("Route 1A", style: TextStyle(color: Colors.grey)),
              ],
            ),
            Column(
              children: const [
                Icon(Icons.directions_bus, color: Colors.grey, size: 28),
                SizedBox(height: 4),
                Text("Platform 3", style: TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildQuickActionButton(Icons.map_outlined, "Map"),
        _buildQuickActionButton(Icons.star_border, "Favorites"),
        _buildQuickActionButton(Icons.history, "History"),
        _buildQuickActionButton(Icons.confirmation_number_outlined, "Tickets"),
      ],
    );
  }

  Widget _buildQuickActionButton(IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.grey[200],
          child: Icon(icon, size: 28, color: Colors.black54),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildNearbyShuttleCard(String route, String distance, String arrival) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: const Icon(Icons.directions_bus, color: Colors.blue, size: 36),
        title: Text(route, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(distance),
        trailing: Text(arrival, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        onTap: () {
          // Handle tap on nearby shuttle
        },
      ),
    );
  }

  Widget _buildRecentRouteCard(String routePath, String dateTime) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        title: Text(routePath, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(dateTime, style: const TextStyle(color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // Handle tap on recent route
        },
      ),
    );
  }
}
