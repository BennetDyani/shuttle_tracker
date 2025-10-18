import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shuttle_tracker/screens/authentication/login_screen.dart';
import 'package:shuttle_tracker/services/APIService.dart';
import 'package:shuttle_tracker/models/User.dart';
import 'package:shuttle_tracker/models/driver_model/Driver.dart';
import 'package:shuttle_tracker/models/driver_model/Shuttle.dart' as ShuttleModel;
import 'package:shuttle_tracker/models/admin_model/Complaint.dart';
import 'package:shuttle_tracker/services/logger.dart';

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

  // Converted mock summary data to stateful variables with initial fallback values
  int totalStudents = 3200;
  int activeDrivers = 15;
  int suspendedDrivers = 2;
  int availableShuttles = 7;
  int inServiceShuttles = 8;
  int openComplaints = 12;
  int resolvedComplaints = 30;
  // Totals for debugging and summary consistency
  int totalDriversCount = 0;
  int totalShuttlesCount = 0;
  int totalComplaintsCount = 0;

  // New: suspended accounts overview
  int suspendedAccounts = 0;
  List<String> suspendedAccountNames = [];

  // New: preview list of suspended drivers for the Drivers section
  List<Map<String, String>> suspendedDriversPreview = [];

  bool _loading = true;
  String? _error;

  // Recent activity will be built from real data where possible
  List<Map<String, String>> recentActivity = [
    {'icon': 'info', 'desc': 'Loading recent activity...', 'time': ''},
  ];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  // Helper to parse dates from various API formats (ISO string or epoch seconds/ms)
  DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    try {
      if (value is String) {
        return DateTime.tryParse(value);
      }
      if (value is int) {
        // Heuristic: if value looks like seconds (10 digits), convert to ms
        if (value.toString().length <= 10) return DateTime.fromMillisecondsSinceEpoch(value * 1000);
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is double) {
        final intVal = value.toInt();
        if (intVal.toString().length <= 10) return DateTime.fromMillisecondsSinceEpoch(intVal * 1000);
        return DateTime.fromMillisecondsSinceEpoch(intVal);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _loading = true;
      _error = null;
      suspendedDriversPreview = [];
    });

    try {
      final api = APIService();

      // We'll keep track of drivers discovered while parsing users as a fallback
      int totalDriversFromUsers = 0;

      // Fetch users (students + others)
      final usersData = await api.get('users/getAll');
      // Normalize wrapped responses where backend may return { data: [...] } or { users: [...] }
      dynamic usersList = usersData;
      if (usersData is Map<String, dynamic>) {
        if (usersData['data'] is List) usersList = usersData['data'];
        else if (usersData['users'] is List) usersList = usersData['users'];
      }
      // Continue processing only if we have a list
      if (usersList is List) {
        // Count students by Role if Role is included; fallback to total users
        try {
          final users = usersList.map((u) => User.fromJson(u)).toList();
          totalStudents = users.where((u) => u.role.toString().contains('STUDENT')).length;
        } catch (_) {
          totalStudents = usersList.length;
        }

        // Compute suspended accounts from raw user objects where possible
        try {
          int suspendedCount = 0;
          final List<String> suspendedNames = [];
          int suspendedDriversCount = 0;
          // do not redeclare totalDriversFromUsers here; update the outer-scope counter
           final List<Map<String, String>> driversPreview = [];

          for (final raw in usersList) {
            if (raw is Map<String, dynamic>) {
              // Compute a stable display name up-front so all branches can use it
              final name = ((raw['name'] ?? raw['first_name'] ?? raw['firstName'] ?? '')?.toString() ?? '') +
                  ' ' +
                  ((raw['surname'] ?? raw['last_name'] ?? raw['lastName'] ?? '')?.toString() ?? '');
              final displayName = name.trim().isNotEmpty ? name.trim() : (raw['email']?.toString() ?? 'Unknown');

              final status = (raw['status'] ?? raw['user_status'] ?? raw['account_status'])?.toString().toUpperCase();
              final boolFlag = (raw['is_suspended'] ?? raw['suspended'] ?? raw['isSuspended']) ?? false;
              final isSuspBool = (boolFlag is bool && boolFlag) || (boolFlag is String && boolFlag.toString().toLowerCase() == 'true');

              final isResigned = (raw['resigned'] == true) || (raw['is_resigned'] == true) || (status == 'RESIGNED');
              final isSuspended = (status == 'SUSPENDED') || isSuspBool || isResigned;

              if (isSuspended) {
                suspendedCount++;
                suspendedNames.add(displayName);

                // If role exists, check if driver
                final roleStr = (raw['role'] ?? raw['role_name'])?.toString().toUpperCase() ?? '';
                if (roleStr.contains('DRIVER')) suspendedDriversCount++;

                // Try to add to recent activity if there's a suspension/resignation timestamp
                final dt = _tryParseDate(raw['suspension_date'] ?? raw['suspended_at'] ?? raw['resigned_at'] ?? raw['updatedAt'] ?? raw['updated_at'] ?? raw['modified_at'] ?? raw['modifiedAt']);
                final when = dt ?? DateTime.now();
                // Only include if within last 30 days (reasonable recent window)
                if (DateTime.now().difference(when).inDays <= 30) {
                  recentActivity.add({
                    'icon': 'report',
                    'desc': '${displayName} ${isResigned ? 'resigned' : 'was suspended'}',
                    'time': _formatTimeAgo(when),
                  });
                }
              }
              // Count drivers from users list (fallback if drivers endpoint unavailable)
              final roleStr2 = (raw['role'] ?? raw['role_name'])?.toString().toUpperCase() ?? '';
              if (roleStr2.contains('DRIVER')) {
                totalDriversFromUsers++;
                // If this driver is suspended, add a preview entry
                final isDriverSusp = (raw['status'] ?? raw['user_status'])?.toString().toUpperCase() == 'SUSPENDED' ||
                    (raw['is_suspended'] ?? raw['suspended'] ?? false) == true ||
                    (raw['resigned'] == true) || (raw['is_resigned'] == true);
                if (isDriverSusp) {
                  final license = (raw['driver_license'] ?? raw['license'] ?? raw['driverLicense'])?.toString() ?? '-';
                  final dt2 = _tryParseDate(raw['suspension_date'] ?? raw['suspended_at'] ?? raw['resigned_at'] ?? raw['updatedAt'] ?? raw['updated_at']);
                  final when2 = dt2 ?? DateTime.now();
                  driversPreview.add({'name': displayName, 'license': license, 'time': _formatTimeAgo(when2)});
                }
              }
            }
          }

          suspendedAccounts = suspendedCount;
          suspendedAccountNames = suspendedNames;
          // If we found a suspended drivers count from users list, prefer it
          if (suspendedDriversCount >= 0) suspendedDrivers = suspendedDriversCount;
          // Populate suspendedDriversPreview from driversPreview if available
          if (driversPreview.isNotEmpty) suspendedDriversPreview = driversPreview.take(6).toList();
          // If drivers endpoint fails later, fallback to counts from users
          if (totalDriversFromUsers > 0) {
            if (suspendedDrivers <= totalDriversFromUsers) activeDrivers = totalDriversFromUsers - suspendedDrivers;
            else activeDrivers = totalDriversFromUsers;
          }
          // Immediately update UI and log values to help debug missing numbers
          setState(() {});
          AppLogger.debug('Dashboard users processed', data: {'totalStudents': totalStudents, 'suspendedAccounts': suspendedAccounts, 'suspendedDrivers': suspendedDrivers});
        } catch (_) {
          // ignore and keep defaults
        }
      }
      else {
        // usersList wasn't a list; keep defaults
      }

      // Fetch drivers
      final driversData = await api.get('drivers/getAll');
      // Normalize driversData similarly
      dynamic driversList = driversData;
      if (driversData is Map<String, dynamic>) {
        if (driversData['data'] is List) driversList = driversData['data'];
        else if (driversData['drivers'] is List) driversList = driversData['drivers'];
      }
      int totalDrivers = 0;
      if (driversList is List) {
        try {
          final drivers = driversList.map((d) => Driver.fromJson(d)).toList();
          // prefer the drivers count from endpoint when available
          totalDrivers = drivers.length;
        } catch (_) {
          totalDrivers = driversList.length;
        }
      } else {
        // No dedicated drivers list; fall back to counts derived from users
        totalDrivers = totalDriversFromUsers;
      }

      // Compute activeDrivers using suspendedDrivers (already derived from users above)
      if (totalDrivers >= 0) {
        if (suspendedDrivers >= 0 && suspendedDrivers <= totalDrivers) activeDrivers = totalDrivers - suspendedDrivers;
        else activeDrivers = totalDrivers;
      }
      AppLogger.debug('Dashboard drivers processed', data: {'totalDrivers': totalDrivers, 'activeDrivers': activeDrivers, 'suspendedDrivers': suspendedDrivers});
      totalDriversCount = totalDrivers;

      // Fetch shuttles
      final shuttlesData = await api.get('shuttles/getAll');
      dynamic shuttlesList = shuttlesData;
      if (shuttlesData is Map<String, dynamic>) {
        if (shuttlesData['data'] is List) shuttlesList = shuttlesData['data'];
        else if (shuttlesData['shuttles'] is List) shuttlesList = shuttlesData['shuttles'];
      }
      if (shuttlesList is List) {
        try {
          final shuttles = shuttlesList.map((s) => ShuttleModel.Shuttle.fromJson(s)).toList();
          availableShuttles = shuttles.where((s) => s.shuttleStatus.toString().toLowerCase().contains('available') || s.shuttleStatus.toString().toLowerCase().contains('active')).length;
          inServiceShuttles = shuttles.length - availableShuttles;
          totalShuttlesCount = shuttles.length;
        } catch (_) {
          // fallback to raw count
          availableShuttles = shuttlesList.length;
          inServiceShuttles = 0;
          totalShuttlesCount = shuttlesList.length;
        }
      } else {
        // fallback: no shuttle endpoint data, leave defaults
      }

      // Fetch complaints
      final complaintsData = await api.get('complaints/getAll');
      dynamic complaintsList = complaintsData;
      if (complaintsData is Map<String, dynamic>) {
        if (complaintsData['data'] is List) complaintsList = complaintsData['data'];
        else if (complaintsData['complaints'] is List) complaintsList = complaintsData['complaints'];
      }
      if (complaintsList is List) {
        try {
          final complaints = complaintsList.map((c) => Complaint.fromJson(c)).toList();
          openComplaints = complaints.where((c) => c.status.toString().toLowerCase().contains('open') || c.status.toString().toLowerCase().contains('pending')).length;
          resolvedComplaints = complaints.length - openComplaints;
          totalComplaintsCount = complaints.length;

          // Build recent activity from the most recent complaints and drivers
          final recent = <Map<String, String>>[];
          final recentComplaints = complaints.take(5);
          for (final c in recentComplaints) {
            recent.add({'icon': 'report', 'desc': '${c.subject} (by ${c.user.name})', 'time': '${_formatTimeAgo(c.createdAt)}'});
          }

          // Optionally add recent drivers or notifications
          // Append to recentActivity only if we have entries
          if (recent.isNotEmpty) recentActivity = recent + recentActivity; // keep any suspension items discovered earlier
        } catch (_) {
          // fallback: use raw list counts
          openComplaints = complaintsList.length;
          resolvedComplaints = 0;
          totalComplaintsCount = complaintsList.length;
        }
      } else {
        // fallback: no complaints endpoint data, leave defaults
      }

      // If we didn't populate recentActivity above, try to create basic entries from drivers or shuttles
      if (recentActivity.isEmpty || (recentActivity.length == 1 && recentActivity[0]['desc'] == 'Loading recent activity...')) {
        final fallbackRecent = <Map<String, String>>[];
        fallbackRecent.add({'icon': 'info', 'desc': 'Dashboard updated', 'time': 'just now'});
        recentActivity = fallbackRecent;
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} d ago';
  }

  void _onBottomNavItemTapped(int index) {
    if (_selectedIndex == index) return;
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/admin/dashboard');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/admin/users');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/admin/shuttles');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/admin/notifications');
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/admin/profile');
        break;
      default:
        Navigator.pushReplacementNamed(context, '/admin/dashboard');
    }
  }

  Widget _summaryCard({required String label, required String value, required IconData icon, required Color color}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha(38),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(label, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _summaryCard(label: 'Students', value: totalStudents.toString(), icon: Icons.person, color: Colors.blue),
          const SizedBox(width: 10),
          _summaryCard(label: 'Drivers (A/S)', value: '$activeDrivers/$suspendedDrivers', icon: Icons.directions_car, color: Colors.teal),
          const SizedBox(width: 10),
          _summaryCard(label: 'Shuttles (Avail/InSvc)', value: '$availableShuttles/$inServiceShuttles', icon: Icons.directions_bus, color: Colors.deepPurple),
          const SizedBox(width: 10),
          _summaryCard(label: 'Complaints (O/R)', value: '$openComplaints/$resolvedComplaints', icon: Icons.warning, color: Colors.orange),
        ],
      ),
    );
  }

  Widget _buildGraphSection(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 180,
        alignment: Alignment.center,
        child: Text('Daily Shuttle Usage Trends (Graph Placeholder)',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
      ),
    );
  }

  Widget _buildRecentActivityFeed(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),

            // Suspended accounts summary
            if (!_loading && suspendedAccounts > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Suspended/Resigned: $suspendedAccounts', style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/admin/users'),
                      child: const Text('View all'),
                    ),
                  ],
                ),
              ),

            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
            if (_error != null) Padding(padding: const EdgeInsets.all(8.0), child: Text('Error: ' + (_error ?? ''), style: const TextStyle(color: Colors.red))),
            if (!_loading && _error == null)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentActivity.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = recentActivity[index];
                  IconData icon;
                  switch (item['icon']) {
                    case 'person': icon = Icons.person; break;
                    case 'report': icon = Icons.report; break;
                    case 'notification': icon = Icons.notifications; break;
                    default: icon = Icons.info;
                  }
                  return ListTile(
                    leading: Icon(icon, color: Colors.blueGrey),
                    title: Text(item['desc'] ?? ''),
                    subtitle: Text(item['time'] ?? '', style: const TextStyle(fontSize: 12)),
                  );
                },
              ),

            // If there are suspended names, show a compact preview
            if (!_loading && suspendedAccountNames.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('Examples:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: suspendedAccountNames.take(6).map((n) => Chip(label: Text(n, style: const TextStyle(fontSize: 12)))).toList(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // New: Drivers section card (shows active/suspended counts and a short suspended-drivers list)
  Widget _buildDriversSection(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Drivers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton(onPressed: () => Navigator.pushNamed(context, '/admin/users'), child: const Text('Manage')),
              ],
            ),
            const SizedBox(height: 8),
            Text('Active: $activeDrivers   Suspended: $suspendedDrivers', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
            else if (suspendedDriversPreview.isEmpty)
              const Text('No suspended drivers to show', style: TextStyle(color: Colors.black54))
            else
              Column(
                children: suspendedDriversPreview.map((d) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person, size: 18, color: Colors.teal),
                  title: Text(d['name'] ?? ''),
                  subtitle: Text('License: ${d['license'] ?? '-'} · ${d['time'] ?? ''}', style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(icon: const Icon(Icons.info_outline), onPressed: () => Navigator.pushNamed(context, '/admin/users')),
                )).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionButton(String label, IconData icon, String routeName) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      onPressed: () => Navigator.pushNamed(context, routeName),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _quickActionButton('Add Driver', Icons.person_add, '/admin/users'),
        _quickActionButton('Fleet Management', Icons.directions_bus, '/admin/shuttles'),
        _quickActionButton('Send Notification', Icons.send, '/admin/notifications'),
        _quickActionButton('View Complaints', Icons.report, '/admin/complaints'),
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
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
        actions: [
          IconButton(
              icon: Icon(Icons.notifications_none, color: theme.colorScheme.onPrimary),
              onPressed: () {
                Navigator.pushNamed(context, '/admin/notifications');
              }),
          // Fleet nav button
          IconButton(
            icon: Icon(Icons.directions_bus, color: theme.colorScheme.onPrimary),
            tooltip: 'Fleet',
            onPressed: () => Navigator.pushNamed(context, '/admin/fleet'),
          ),
           PopupMenuButton<String>(
            icon: const CircleAvatar(child: Icon(Icons.person)),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Navigator.pushNamed(context, '/admin/profile');
                  break;
                case 'logout':
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'profile', child: Text('View Profile')),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCards(context),
            // Debug panel to surface current numeric state when running in debug mode
            if (kDebugMode) const SizedBox(height: 8),
            if (kDebugMode) _buildDebugPanel(context),
            const SizedBox(height: 18),
            _buildGraphSection(context),
            const SizedBox(height: 18),
            _buildRecentActivityFeed(context),
            const SizedBox(height: 18),
            _buildDriversSection(context),
            const SizedBox(height: 18),
            _buildQuickActions(context),
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
        unselectedItemColor: theme.colorScheme.onSurface.withAlpha(153),
        showUnselectedLabels: true,
        onTap: _onBottomNavItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  // Debug panel that shows current computed values to help troubleshoot missing numbers
  Widget _buildDebugPanel(BuildContext context) {
    return Card(
      color: Colors.grey[50],
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            Text('Debug: ActiveDrivers=$activeDrivers', style: const TextStyle(fontSize: 12, color: Colors.black87)),
            Text('SuspendedDrivers=$suspendedDrivers', style: const TextStyle(fontSize: 12, color: Colors.black87)),
            Text('SuspendedAccounts=$suspendedAccounts', style: const TextStyle(fontSize: 12, color: Colors.black87)),
            Text('TotalStudents=$totalStudents', style: const TextStyle(fontSize: 12, color: Colors.black87)),
            Text('TotalDrivers=$totalDriversCount', style: const TextStyle(fontSize: 12, color: Colors.black87)),
            Text('TotalShuttles=$totalShuttlesCount', style: const TextStyle(fontSize: 12, color: Colors.black87)),
            Text('TotalComplaints=$totalComplaintsCount', style: const TextStyle(fontSize: 12, color: Colors.black87)),
            if (_error != null) Text('LastError=${_error}', style: const TextStyle(fontSize: 12, color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
