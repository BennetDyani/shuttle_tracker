import 'package:flutter/material.dart';
import 'package:shuttle_tracker/screens/admin/admin_home_screen.dart';
import 'package:shuttle_tracker/screens/admin/admin_shuttle_screen.dart';
import 'package:shuttle_tracker/screens/admin/admin_stats_screen.dart';
import 'package:shuttle_tracker/screens/admin/admin_users_screen.dart'; // Import AdminUsersScreen
// import 'package:shuttle_tracker/screens/authentication/login_screen.dart'; // For logout

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final int _selectedIndex = 4; // "Settings" is highlighted
  bool _notificationsEnabled = true;

  void _onBottomNavItemTapped(int index) {
    if (_selectedIndex == index) return;

    Widget pageBuilder(BuildContext context) {
      switch (index) {
        case 0:
          return const AdminHomeScreen();
        case 1:
          return const AdminUsersScreen(); // Navigate to AdminUsersScreen
        case 2:
          return const AdminShuttleScreen();
        case 3:
          return const AdminStatsScreen();
        case 4:
          return const AdminSettingsScreen(); // Current screen
        default:
          return const AdminSettingsScreen(); // Fallback
      }
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => pageBuilder(context),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
      child: Text(
        title,
        style: Theme
            .of(context)
            .textTheme
            .titleMedium
            ?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme
              .of(context)
              .colorScheme
              .primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.colorScheme.primary,
        titleTextStyle: TextStyle(
          color: theme.colorScheme.onPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
      ),
      body: ListView(
        children: <Widget>[
          _buildSectionTitle(context, 'General Settings'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.miscellaneous_services_outlined),
                  title: const Text('App Configuration'),
                  subtitle: const Text('System parameters and defaults'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('App Configuration tapped')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Notifications'),
                  subtitle: const Text('Manage alerts and sounds'),
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: (bool value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Notifications ${value
                            ? "Enabled"
                            : "Disabled"}')),
                      );
                    },
                    activeColor: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          _buildSectionTitle(context, 'Account Settings'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: const Text('Profile Settings'),
                  subtitle: const Text('Edit admin details'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile Settings tapped')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Change Password tapped')),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.logout, color: theme.colorScheme.error),
                  title: Text('Logout',
                      style: TextStyle(color: theme.colorScheme.error)),
                  onTap: () {
                    showDialog(
                        context: context,
                        builder: (BuildContext ctx) {
                          return AlertDialog(
                            title: const Text('Confirm Logout'),
                            content: const Text(
                                'Are you sure you want to log out?'),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('Cancel'),
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                },
                              ),
                              TextButton(
                                child: Text('Logout', style: TextStyle(
                                    color: theme.colorScheme.error)),
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Logged out')),
                                  );
                                  // TODO: Navigate to LoginScreen
                                  // Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                                },
                              ),
                            ],
                          );
                        });
                  },
                ),
              ],
            ),
          ),
          _buildSectionTitle(context, 'System Management'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: const Text('Audit Logs'),
                  subtitle: const Text('View system and user activity'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Audit Logs tapped')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Data Backup'),
                  subtitle: const Text('Manage system backups'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Data Backup tapped')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('System Version'),
                  subtitle: const Text('1.0.0 (Build 20240315)'),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus),
            label: 'Shuttles',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
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