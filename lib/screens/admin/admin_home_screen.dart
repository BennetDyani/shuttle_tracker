import 'package:flutter/material.dart';
import 'package:shuttle_tracker/screens/admin/admin_shuttle_screen.dart';
import 'package:shuttle_tracker/screens/admin/admin_stats_screen.dart';
import 'package:shuttle_tracker/screens/admin/admin_settings_screen.dart';
import 'package:shuttle_tracker/screens/admin/admin_users_screen.dart';

// Mirrored Shuttle Model (Ideally, this should be in a shared models file)
class Shuttle {
  final String id;
  String name;
  String plateNumber;
  int capacity;
  String shuttleType; // "Bus", "Minibus"
  String startingPoint;
  String destination;
  String? driverName;
  String status; // "Active", "Inactive", "Maintenance"

  Shuttle({
    required this.id,
    required this.name,
    required this.plateNumber,
    required this.capacity,
    required this.shuttleType,
    required this.startingPoint,
    required this.destination,
    this.driverName,
    required this.status,
  });
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final int _selectedIndex = 0;

  // Mirrored Shuttle Data (This should come from a shared data source for true sync)
  // This is a snapshot based on the data in AdminShuttleScreen
  final List<Shuttle> _shuttleDataSource = [
    Shuttle(id: 'S101',
        name: 'Campus Express',
        plateNumber: 'CA 123-456',
        capacity: 25,
        shuttleType: 'Bus',
        startingPoint: 'Main Campus',
        destination: 'North Residence',
        driverName: 'Jane Doe',
        status: 'Active'),
    Shuttle(id: 'S102',
        name: 'City Link',
        plateNumber: 'CB 789-012',
        capacity: 15,
        shuttleType: 'Minibus',
        startingPoint: 'Bellville Station',
        destination: 'District 6 Hub',
        driverName: 'John Smith',
        status: 'Inactive'),
    Shuttle(id: 'S103',
        name: 'Tech Runner',
        plateNumber: 'CC 345-678',
        capacity: 20,
        shuttleType: 'Bus',
        startingPoint: 'Tech Park Gate 1',
        destination: 'Central Library',
        status: 'Maintenance'),
    Shuttle(id: 'S104',
        name: 'Alpha Mover',
        plateNumber: 'CD 901-234',
        capacity: 15,
        shuttleType: 'Minibus',
        startingPoint: 'Waterfront Mall',
        destination: 'City Center',
        driverName: 'Alex Green',
        status: 'Active'),
    // Add more shuttles here if they exist in AdminShuttleScreen to keep the data consistent for this demonstration
  ];

  void _onBottomNavItemTapped(int index) {
    if (_selectedIndex == index) return;
    Widget pageBuilder(BuildContext context) {
      switch (index) {
        case 0:
          return const AdminHomeScreen();
        case 1:
          return const AdminUsersScreen();
        case 2:
          return const AdminShuttleScreen();
        case 3:
          return const AdminStatsScreen();
        case 4:
          return const AdminSettingsScreen();
        default:
          return const AdminHomeScreen();
      }
    }
    Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => pageBuilder(context),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero));
  }

  Widget _buildSystemStatsCards(BuildContext context) {
    // Calculate active shuttles from the local data source
    int activeShuttlesCount = _shuttleDataSource
        .where((shuttle) => shuttle.status == 'Active')
        .length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            'Active Users',
            // Placeholder value, consider a similar sync mechanism for users if needed
            '2,456',
            Theme
                .of(context)
                .colorScheme
                .primaryContainer,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            context,
            'Active Shuttles',
            activeShuttlesCount.toString(), // Use the calculated count
            Theme
                .of(context)
                .colorScheme
                .secondaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String count,
      Color cardColor) {
    final theme = Theme.of(context);
    Color contentColor;
    if (cardColor == theme.colorScheme.primaryContainer) {
      contentColor = theme.colorScheme.onPrimaryContainer;
    } else if (cardColor == theme.colorScheme.secondaryContainer) {
      contentColor = theme.colorScheme.onSecondaryContainer;
    } else if (cardColor == theme.colorScheme.tertiaryContainer) {
      contentColor = theme.colorScheme.onTertiaryContainer;
    } else if (cardColor == theme.colorScheme.errorContainer) {
      contentColor = theme.colorScheme.onErrorContainer;
    } else {
      contentColor =
      cardColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    }

    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              count,
              style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold, color: contentColor),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: contentColor.withOpacity(0.8)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserManagementSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('User Management', style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              icon: Icon(
                  Icons.add, color: theme.colorScheme.onPrimary, size: 18),
              label: Text('Add User',
                  style: TextStyle(color: theme.colorScheme.onPrimary)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (
                      _) => const AdminUsersScreen())), // Or use the bottom nav logic if preferred
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Text('JS', style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold))),
            title: const Text('John Smith (Recent)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Student - Last login: 2h ago'),
            trailing: IconButton(icon: Icon(
                Icons.more_vert, color: theme.colorScheme.onSurfaceVariant),
                onPressed: () {}),
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildComplaintsSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Complaints',
                style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold)),
            TextButton(onPressed: () {}, child: const Text('View All'))
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Icon(
                Icons.report_problem_outlined, color: theme.colorScheme.error,
                size: 28),
            title: const Text('Shuttle Delay, Route #103',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('15min delay reported by user - Jane D.'),
            trailing: Chip(label: const Text(
                'Open', style: TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: Colors.orange.shade700,
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2)),
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick System Overview',
            style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceVariant,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: Container(
            height: 150,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16.0),
            child: Text(
                'Performance Chart Placeholder\n(e.g., On-time Departures)',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        elevation: 1,
        title: Text('Admin Dashboard', style: TextStyle(
            color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
        actions: [
          IconButton(icon: Icon(
              Icons.notifications_none, color: theme.colorScheme.onPrimary),
              onPressed: () {}),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 8.0),
            child: CircleAvatar(
                backgroundColor: theme.colorScheme.onPrimary.withOpacity(0.2),
                child: Icon(Icons.person, color: theme.colorScheme.onPrimary)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSystemStatsCards(context),
            const SizedBox(height: 24),
            _buildUserManagementSection(context),
            const SizedBox(height: 24),
            _buildComplaintsSection(context),
            const SizedBox(height: 24),
            _buildPerformanceSection(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(
              icon: Icon(Icons.directions_bus), label: 'Shuttles'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
        showUnselectedLabels: true,
        onTap: _onBottomNavItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}