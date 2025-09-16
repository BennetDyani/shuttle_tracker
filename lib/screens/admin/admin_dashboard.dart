import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AuthService _authService = AuthService();
  int _currentIndex = 0;

  final List<Widget> _screens = [
    _buildOverviewTab(),
    _buildUsersTab(),
    _buildShuttlesTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.red[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus),
            label: 'Shuttles',
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    Navigator.pushReplacementNamed(context, '/admin/login');
  }

  static Widget _buildOverviewTab() {
    return const Center(
      child: Text('Admin Overview - Coming Soon'),
    );
  }

  static Widget _buildUsersTab() {
    return const Center(
      child: Text('User Management - Coming Soon'),
    );
  }

  static Widget _buildShuttlesTab() {
    return const Center(
      child: Text('Shuttle Management - Coming Soon'),
    );
  }
}