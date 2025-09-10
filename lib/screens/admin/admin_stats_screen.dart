import 'package:flutter/material.dart';

import 'package:shuttle_tracker/screens/admin/admin_home_screen.dart';
import 'package:shuttle_tracker/screens/admin/admin_shuttle_screen.dart';
import 'package:shuttle_tracker/screens/admin/admin_settings_screen.dart';
import 'package:shuttle_tracker/screens/admin/admin_users_screen.dart';

// Placeholder for a charting library you might add, e.g., fl_chart
// import 'package:fl_chart/fl_chart.dart';

// Complaint Model (Mirrored - ideally in a shared models file)
class Complaint {
  final String id;
  final String title;
  final String description;
  final String reportedBy; // Could be a User ID or name
  final DateTime dateReported;
  String status; // "Open", "Pending", "Resolved"

  Complaint({
    required this.id,
    required this.title,
    required this.description,
    required this.reportedBy,
    required this.dateReported,
    required this.status,
  });
}

class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  final int _selectedIndex = 3;

  // Sample Complaints Data (Mirrored)
  final List<Complaint> _complaintsDataSource = [
    Complaint(id: 'C001',
        title: 'Shuttle S101 Overcrowded',
        description: 'The 9 AM shuttle was too full, many students left behind.',
        reportedBy: 'Alice W.',
        dateReported: DateTime.now().subtract(const Duration(hours: 2)),
        status: 'Open'),
    Complaint(id: 'C002',
        title: 'Driver Late for Route 3B',
        description: 'Driver for S102 was 15 minutes late this morning.',
        reportedBy: 'Admin Staff',
        dateReported: DateTime.now().subtract(const Duration(hours: 5)),
        status: 'Pending'),
    Complaint(id: 'C003',
        title: 'AC Not Working on S104',
        description: 'The air conditioning on shuttle S104 seems to be broken.',
        reportedBy: 'Bob B.',
        dateReported: DateTime.now().subtract(const Duration(days: 1)),
        status: 'Resolved'),
    Complaint(id: 'C004',
        title: 'Website Login Issue',
        description: 'Student reported being unable to login to track shuttles.',
        reportedBy: 'Tech Support',
        dateReported: DateTime.now().subtract(const Duration(days: 2)),
        status: 'Open'),
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
          return const AdminStatsScreen();
      }
    }
    Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => pageBuilder(context),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    int openComplaintsCount = _complaintsDataSource
        .where((c) => c.status == 'Open')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics & Performance'),
        backgroundColor: theme.colorScheme.primary,
        titleTextStyle: TextStyle(color: theme.colorScheme.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold),
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildKeyMetricsSection(context, openComplaintsCount),
          const SizedBox(height: 24),
          _buildChartsSection(context),
          const SizedBox(height: 24),
          _buildComplaintsListSection(context), // Renamed from recent activity
        ],
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

  Widget _buildKeyMetricsSection(BuildContext context,
      int openComplaintsCount) {
    final theme = Theme.of(context);
    // These would ideally come from a central data service
    const String totalUsersToday = "1,234";
    const String activeShuttles = "15"; // This should also be synced if possible
    const String ticketsSold = "350";


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text('Key Metrics',
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 120, // Adjusted height for cards
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              _buildMetricCard(context, 'Total Users Today', totalUsersToday,
                  Icons.person_outline, theme.colorScheme.primaryContainer,
                  theme.colorScheme.onPrimaryContainer),
              _buildMetricCard(context, 'Active Shuttles', activeShuttles,
                  Icons.directions_bus_filled_outlined,
                  theme.colorScheme.secondaryContainer,
                  theme.colorScheme.onSecondaryContainer),
              _buildMetricCard(context, 'Tickets Sold', ticketsSold,
                  Icons.confirmation_number_outlined,
                  theme.colorScheme.tertiaryContainer,
                  theme.colorScheme.onTertiaryContainer),
              _buildMetricCard(
                  context, 'Open Complaints', openComplaintsCount.toString(),
                  Icons.report_problem_outlined,
                  theme.colorScheme.errorContainer,
                  theme.colorScheme.onErrorContainer),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value,
      IconData icon, Color bgColor, Color contentColor) {
    final theme = Theme.of(context);
    return Card(
      color: bgColor,
      elevation: 0, // Flat design for these cards
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 160, // Fixed width for horizontal scroll
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Icon(icon, size: 28, color: contentColor.withOpacity(0.8)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold, color: contentColor)),
                Text(title, style: theme.textTheme.bodySmall?.copyWith(
                    color: contentColor.withOpacity(0.7)),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text('Performance Insights',
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold)),
        ),
        // TODO: Replace placeholders with actual chart widgets (e.g., using fl_chart)
        _buildChartCard(context, 'Shuttle Utilization by Route',
            'Bar Chart: Shuttle Utilization\n(Requires charting library & data source)'),
        const SizedBox(height: 16),
        _buildChartCard(context, 'Ticket Sales Trends (Monthly)',
            'Line Chart: Ticket Sales\n(Requires charting library & data source)'),
        const SizedBox(height: 16),
        _buildChartCard(context, 'Complaint Trends (Weekly)',
            'Line Chart: Complaint Volume\n(Requires charting library & data source)'),
      ],
    );
  }

  Widget _buildChartCard(BuildContext context, String title,
      String placeholderText) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              height: 150,
              decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8),
              // Padding for placeholder text
              child: Text(
                placeholderText,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 8),
            // Placeholder for chart legend or filters if needed
            // Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton(onPressed: () {}, child: Text("View Details"))])
          ],
        ),
      ),
    );
  }

  Widget _buildComplaintsListSection(BuildContext context) {
    final theme = Theme.of(context);
    if (_complaintsDataSource.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(child: Text('No complaints logged recently.',
            style: theme.textTheme.titleMedium)),
      );
    }

    // Sort complaints by date, newest first
    List<Complaint> sortedComplaints = List.from(_complaintsDataSource);
    sortedComplaints.sort((a, b) => b.dateReported.compareTo(a.dateReported));


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text('Recent Complaints',
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold)),
        ),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: sortedComplaints.take(5).map((
                complaint) { // Show top 5 recent complaints
              IconData statusIcon;
              Color statusColor;
              switch (complaint.status) {
                case 'Open':
                  statusIcon = Icons.folder_open_outlined;
                  statusColor = theme.colorScheme.error;
                  break;
                case 'Pending':
                  statusIcon = Icons.hourglass_empty_outlined;
                  statusColor = Colors.orange.shade700;
                  break;
                case 'Resolved':
                  statusIcon = Icons.check_circle_outline;
                  statusColor = Colors.green.shade700;
                  break;
                default:
                  statusIcon = Icons.help_outline;
                  statusColor = Colors.grey;
              }
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Icon(statusIcon, color: statusColor, size: 22),
                ),
                title: Text(complaint.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600)),
                subtitle: Text(
                    'Reported by ${complaint.reportedBy} on ${complaint
                        .dateReported.toLocal().toString().substring(0, 10)}',
                    style: theme.textTheme.bodySmall),
                trailing: Text(complaint.status, style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
                onTap: () {
                  // TODO: Implement navigation to a complaint details screen or show a dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('View details for: ${complaint
                          .title}')));
                },
              );
            }).toList(),
          ),
        ),
        if (sortedComplaints.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // TODO: Navigate to a full complaints screen
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('View all complaints (not implemented)')));
                },
                child: const Text('View All Complaints'),
              ),
            ),
          ),
      ],
    );
  }
}