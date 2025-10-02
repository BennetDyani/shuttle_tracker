import 'package:flutter/material.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.blue[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // Handle notifications
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: Text('DEBUG', style: TextStyle(color: Colors.white))),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsRow(),
            const SizedBox(height: 20),
            _buildUserManagementSection(),
            const SizedBox(height: 20),
            _buildComplaintsSection(),
            const SizedBox(height: 20),
            _buildPerformanceChartPlaceholder(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue[900],
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_bus), label: 'Shuttles'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard('2,456 Active Users', Icons.person),
        const SizedBox(width: 16),
        _buildStatCard('18 Active Shuttles', Icons.directions_bus),
      ],
    );
  }

  Widget _buildStatCard(String label, IconData icon) {
    return Expanded(
      child: Card(
        color: Colors.blue[100],
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: Colors.blue[900]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('User Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: () {
                // Add user logic
              },
              icon: const Icon(Icons.add),
              label: const Text('Add User'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const Icon(Icons.person),
            title: const Text('John Smith'),
            subtitle: const Text('Student'),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // Edit user
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComplaintsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Complaints', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const Icon(Icons.report_problem, color: Colors.orange),
            title: const Text('Shuttle Delay, Route #103'),
            subtitle: const Text('15min delay reported by user'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[600],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Open', style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceChartPlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey),
      ),
      child: const Center(
        child: Text('Performance Chart Placeholder'),
      ),
    );
  }
}