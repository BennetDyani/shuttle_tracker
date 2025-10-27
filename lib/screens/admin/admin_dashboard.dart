import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../authentication/login_screen.dart';
import '../../providers/auth_provider.dart';
import '../../services/APIService.dart';
import '../../services/logger.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final int _selectedIndex = 0;

  // Dashboard statistics
  int totalStudents = 0;
  int activeDrivers = 0;
  int suspendedDrivers = 0;
  int availableShuttles = 0;
  int inServiceShuttles = 0;
  int openComplaints = 0;
  int resolvedComplaints = 0;

  // Totals for summary
  int totalDriversCount = 0;
  int totalShuttlesCount = 0;
  int totalComplaintsCount = 0;
  int totalNotificationsCount = 0;
  int complaintNotificationsCount = 0;

  // Suspended accounts overview
  int suspendedAccounts = 0;
  List<String> suspendedAccountNames = [];
  List<Map<String, String>> suspendedDriversPreview = [];

  bool _loading = true;
  String? _error;
  String _displayName = '';
  bool _isLoadingName = true;

  // Recent activity
  List<Map<String, dynamic>> recentActivity = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _loadName();
  }

  Future<void> _loadName() async {
    if (!mounted) return;

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uidStr = auth.userId;
      if (uidStr == null || uidStr.isEmpty) {
        throw Exception('Not logged in');
      }

      final uid = int.tryParse(uidStr);
      if (uid == null) {
        throw Exception('Invalid user ID');
      }

      final user = await APIService().fetchUserById(uid);
      if (!mounted) return;

      final first = (user['first_name'] ?? user['firstName'] ?? user['name'] ?? '').toString();
      final last = (user['last_name'] ?? user['lastName'] ?? user['surname'] ?? '').toString();
      final combined = ('$first $last').trim();

      setState(() {
        _displayName = combined.isEmpty ? (user['email']?.toString() ?? 'Admin') : combined;
        _isLoadingName = false;
      });
    } catch (e) {
      if (!mounted) return;
      AppLogger.error('Failed to load admin name', error: e);
      setState(() {
        _displayName = 'Admin'; // Fallback name
        _isLoadingName = false;
        _error = null; // Don't show error to user
      });
    }
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = APIService();

      // Fetch all data in parallel for better performance
      final results = await Future.wait([
        api.fetchShuttles(),
        api.fetchDrivers(),
        api.fetchUsersRaw(), // Use fetchUsersRaw to get Map objects
        api.fetchComplaints().catchError((e) {
          AppLogger.warn('Failed to fetch complaints: $e');
          return <Map<String, dynamic>>[];
        }),
      ]);

      if (!mounted) return;

      final shuttles = results[0] as List<dynamic>;
      final drivers = results[1] as List<dynamic>;
      final users = results[2] as List<dynamic>;
      final complaints = results[3] as List<Map<String, dynamic>>;

      AppLogger.debug('Fetched data counts: shuttles=${shuttles.length}, drivers=${drivers.length}, users=${users.length}, complaints=${complaints.length}');

      // Count shuttles by status
      int available = 0;
      int inService = 0;
      int maintenance = 0;
      int other = 0;

      for (final shuttle in shuttles) {
        if (shuttle is Map<String, dynamic>) {
          AppLogger.debug('Shuttle data: ${shuttle.toString()}');
          final statusName = shuttle['status_name']?.toString().toLowerCase() ??
                           shuttle['statusName']?.toString().toLowerCase() ??
                           shuttle['status']?.toString().toLowerCase() ?? '';
          AppLogger.debug('Shuttle status parsed: "$statusName"');

          // More comprehensive status matching
          if (statusName.isEmpty) {
            // If no status, assume available
            available++;
          } else if (statusName.contains('available') || statusName == 'active' || statusName == 'ready') {
            available++;
          } else if (statusName.contains('service') || statusName.contains('in_service') || statusName.contains('in-service') || statusName.contains('inservice')) {
            inService++;
          } else if (statusName.contains('maintenance') || statusName.contains('repair')) {
            maintenance++;
          } else {
            other++;
            AppLogger.warn('Unknown shuttle status: "$statusName"');
          }
        }
      }

      AppLogger.debug('Shuttle counts: available=$available, inService=$inService, maintenance=$maintenance, other=$other, total=${shuttles.length}');

      // Count students (users with STUDENT role)
      int studentCount = 0;
      int disabledStudentCount = 0;
      int adminCount = 0;
      int driverCount = 0;
      int noRoleCount = 0;

      AppLogger.debug('Processing ${users.length} users...');

      // Log first few users as samples
      if (users.isNotEmpty && users.length > 0) {
        final sampleCount = users.length > 3 ? 3 : users.length;
        AppLogger.debug('Sample user data (first $sampleCount):');
        for (int i = 0; i < sampleCount; i++) {
          final user = users[i];
          if (user is Map) {
            AppLogger.debug('  User $i (Map): ${user.toString()}');
          } else {
            AppLogger.debug('  User $i (${user.runtimeType}): ${user.toString()}');
          }
        }
      }

      for (final user in users) {
        if (user is Map<String, dynamic>) {
          final userId = user['user_id'] ?? user['userId'] ?? user['id'];
          final roleRaw = user['role'] ?? user['role_name'] ?? user['roleName'] ?? '';
          final role = roleRaw.toString().toUpperCase();

          AppLogger.debug('User $userId: raw role="$roleRaw", parsed role="$role", isEmpty=${role.isEmpty}');

          if (role.isEmpty) {
            noRoleCount++;
            AppLogger.warn('User $userId has NO ROLE assigned!');
          } else if (role.contains('STUDENT')) {
            if (role.contains('DISABLED')) {
              disabledStudentCount++;
              AppLogger.debug('User $userId: DISABLED STUDENT');
            } else {
              AppLogger.debug('User $userId: NORMAL STUDENT');
            }
            studentCount++;
          } else if (role == 'ADMIN' || role == 'ADMINISTRATOR') {
            adminCount++;
            AppLogger.debug('User $userId: ADMIN');
          } else if (role == 'DRIVER') {
            driverCount++;
            AppLogger.debug('User $userId: DRIVER');
          } else {
            AppLogger.warn('User $userId has UNKNOWN ROLE: "$role"');
          }
        }
      }

      AppLogger.debug('User role counts', data: {
        'students': studentCount,
        'disabled_students': disabledStudentCount,
        'admins': adminCount,
        'drivers': driverCount,
        'no_role': noRoleCount,
        'total_users': users.length,
      });

      // Count drivers by status
      int active = 0;
      int suspended = 0;
      final suspendedPreviews = <Map<String, String>>[];

      AppLogger.debug('Processing ${drivers.length} drivers...');

      for (final driver in drivers) {
        if (driver is Map<String, dynamic>) {
          AppLogger.debug('Driver raw data: ${driver.toString()}');

          final status = (driver['status'] ?? '').toString().toLowerCase();
          final driverId = driver['driver_id'] ?? driver['driverId'] ?? driver['id'];

          AppLogger.debug('Driver $driverId status parsed: "$status" (empty=${status.isEmpty})');

          if (status.isEmpty || status == 'active' || status == 'available') {
            active++;
            AppLogger.debug('Driver $driverId counted as ACTIVE');
          } else if (status == 'suspended' || status == 'inactive') {
            suspended++;
            AppLogger.debug('Driver $driverId counted as SUSPENDED');

            // Get driver name from user data or driver data
            String driverName = 'Unknown Driver';
            if (driver['user'] is Map) {
              final user = driver['user'] as Map;
              final firstName = user['first_name'] ?? user['firstName'] ?? '';
              final lastName = user['last_name'] ?? user['lastName'] ?? '';
              driverName = '$firstName $lastName'.trim();
            }
            if (driverName == 'Unknown Driver' || driverName.isEmpty) {
              driverName = driver['name']?.toString() ??
                          driver['driver_name']?.toString() ??
                          'Driver ${driver['driver_id'] ?? driver['id']}';
            }

            suspendedPreviews.add({
              'name': driverName,
              'reason': driver['suspension_reason']?.toString() ??
                       driver['suspensionReason']?.toString() ??
                       'No reason provided'
            });
          } else {
            AppLogger.warn('Driver $driverId has unknown status: "$status" - counting as active by default');
            active++; // Default unknown statuses to active
          }
        }
      }

      AppLogger.debug('Driver counts: active=$active, suspended=$suspended, total=${drivers.length}');

      // Process complaints
      int open = 0;
      int resolved = 0;
      final recentActivityItems = <Map<String, dynamic>>[];

      AppLogger.debug('Processing ${complaints.length} complaints');

      for (final complaint in complaints) {
        if (complaint is Map<String, dynamic>) {
          final status = (complaint['status'] ??
                         complaint['status_name'] ??
                         complaint['statusName'] ??
                         '').toString().toLowerCase();

          AppLogger.debug('Complaint status: $status');

          if (status.isEmpty || status == 'open' || status == 'pending' || status == 'unread' || status == 'new') {
            open++;
          } else if (status == 'resolved' || status == 'closed' || status == 'read' || status == 'completed') {
            resolved++;
          }

          // Add to recent activity if it's new (less than 7 days old)
          final createdAtStr = complaint['created_at']?.toString() ??
                              complaint['createdAt']?.toString() ??
                              complaint['timestamp']?.toString() ??
                              complaint['date']?.toString() ?? '';

          DateTime? createdAt;
          if (createdAtStr.isNotEmpty) {
            createdAt = DateTime.tryParse(createdAtStr);
          }

          if (createdAt != null && DateTime.now().difference(createdAt).inDays < 7) {
            recentActivityItems.add({
              'type': 'complaint',
              'title': complaint['title']?.toString() ??
                      complaint['subject']?.toString() ??
                      'New Complaint',
              'description': complaint['description']?.toString() ??
                           complaint['message']?.toString() ??
                           complaint['details']?.toString() ??
                           'No description provided',
              'created_at': createdAt,
            });
          }
        }
      }

      AppLogger.debug('Complaint counts', data: {
        'open': open,
        'resolved': resolved,
        'total': complaints.length,
        'recent_activity': recentActivityItems.length,
      });

      // Sort recent activity by date (newest first)
      recentActivityItems.sort((a, b) {
        final aDate = a['created_at'] as DateTime;
        final bDate = b['created_at'] as DateTime;
        return bDate.compareTo(aDate);
      });

      // Update state with all fetched data
      if (!mounted) return;
      setState(() {
        totalStudents = studentCount;

        availableShuttles = available;
        inServiceShuttles = inService;
        totalShuttlesCount = shuttles.length;

        activeDrivers = active;
        suspendedDrivers = suspended;
        totalDriversCount = drivers.length;
        suspendedDriversPreview = suspendedPreviews;
        suspendedAccounts = suspended;
        suspendedAccountNames = suspendedPreviews.map((e) => e['name'] ?? '').toList();

        openComplaints = open;
        resolvedComplaints = resolved;
        totalComplaintsCount = complaints.length;
        totalNotificationsCount = complaints.length;
        complaintNotificationsCount = open;

        recentActivity = recentActivityItems;
        _loading = false;
      });

      AppLogger.info('Dashboard data loaded', data: {
        'students': studentCount,
        'disabled_students': disabledStudentCount,
        'shuttles_total': shuttles.length,
        'shuttles_available': available,
        'shuttles_in_service': inService,
        'drivers_total': drivers.length,
        'drivers_active': active,
        'drivers_suspended': suspended,
        'complaints_total': complaints.length,
        'complaints_open': open,
        'complaints_resolved': resolved,
        'recent_activity_items': recentActivityItems.length,
      });

    } catch (e, st) {
      AppLogger.error('Failed to fetch dashboard data', error: e);
      AppLogger.debug('Stack trace: $st');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load dashboard data';
        _loading = false;
      });
    }
  }


  void _onBottomNavItemTapped(int index) {
    if (_selectedIndex == index) return;
    switch (index) {
      case 0:
        // Already on dashboard, do nothing
        return;
      case 1:
        Navigator.pushNamed(context, '/admin/users');
        break;
      case 2:
        Navigator.pushNamed(context, '/admin/shuttles');
        break;
      case 3:
        // Open Manage Schedules screen
        Navigator.pushNamed(context, '/admin/schedules');
        break;
      case 4:
        Navigator.pushNamed(context, '/admin/profile');
        break;
      default:
        // Already on dashboard, do nothing
        return;
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // For very small screens, stack cards vertically
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              _summaryCard(label: 'Students', value: totalStudents.toString(), icon: Icons.person, color: Colors.blue),
              const SizedBox(height: 10),
              _summaryCard(label: 'Drivers (A/S)', value: '$activeDrivers/$suspendedDrivers', icon: Icons.directions_car, color: Colors.teal),
              const SizedBox(height: 10),
              _summaryCard(label: 'Shuttles', value: '$totalShuttlesCount', icon: Icons.directions_bus, color: Colors.deepPurple),
              const SizedBox(height: 10),
              _summaryCard(label: 'Complaints', value: '$totalComplaintsCount', icon: Icons.warning, color: Colors.orange),
            ],
          );
        }
        // For wider screens, use horizontal scroll
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _summaryCard(label: 'Students', value: totalStudents.toString(), icon: Icons.person, color: Colors.blue),
              const SizedBox(width: 10),
              _summaryCard(label: 'Drivers (A/S)', value: '$activeDrivers/$suspendedDrivers', icon: Icons.directions_car, color: Colors.teal),
              const SizedBox(width: 10),
              _summaryCard(label: 'Shuttles', value: '$totalShuttlesCount', icon: Icons.directions_bus, color: Colors.deepPurple),
              const SizedBox(width: 10),
              _summaryCard(label: 'Complaints', value: '$totalComplaintsCount', icon: Icons.warning, color: Colors.orange),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGraphSection(BuildContext context) {
    final List<String> imageList = [
      'assets/images/mainshuttle.jpg',
      'assets/images/shuttle1.jpg',
      'assets/images/shuttle2.jpg',
      'assets/images/shuttle3.jpg',
      'assets/images/shuttle4.jpg',
      'assets/images/shuttle5.jpg',
      'assets/images/shuttle6.jpg',
      'assets/images/shuttle7.jpg',
      'assets/images/shuttle8.jpg',
    ];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: CarouselSlider(
          options: CarouselOptions(
            height: 180,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 3),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            autoPlayCurve: Curves.fastOutSlowIn,
            enlargeCenterPage: true,
            enlargeFactor: 0.3,
          ),
          items: imageList.map((image) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 5.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.asset(
                  image,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            );
          }).toList(),
        ),
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
            if (!_loading && _error == null && recentActivity.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentActivity.length > 5 ? 5 : recentActivity.length, // Show max 5 items
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = recentActivity[index];
                  IconData icon;
                  Color iconColor;

                  // Determine icon based on type
                  final type = item['type']?.toString() ?? '';
                  switch (type) {
                    case 'complaint':
                      icon = Icons.report_problem;
                      iconColor = Colors.orange;
                      break;
                    case 'notification':
                      icon = Icons.notifications;
                      iconColor = Colors.blue;
                      break;
                    case 'user':
                      icon = Icons.person_add;
                      iconColor = Colors.green;
                      break;
                    default:
                      icon = Icons.info;
                      iconColor = Colors.grey;
                  }

                  // Format time ago
                  String timeAgo = '';
                  final createdAt = item['created_at'] as DateTime?;
                  if (createdAt != null) {
                    final diff = DateTime.now().difference(createdAt);
                    if (diff.inMinutes < 1) {
                      timeAgo = 'just now';
                    } else if (diff.inMinutes < 60) {
                      timeAgo = '${diff.inMinutes} min ago';
                    } else if (diff.inHours < 24) {
                      timeAgo = '${diff.inHours} hr ago';
                    } else {
                      timeAgo = '${diff.inDays} d ago';
                    }
                  }

                  return ListTile(
                    leading: Icon(icon, color: iconColor),
                    title: Text(item['title']?.toString() ?? 'Activity'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item['description']?.toString().isNotEmpty == true)
                          Text(
                            item['description'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        if (timeAgo.isNotEmpty)
                          Text(timeAgo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  );
                },
              )
            else if (!_loading && _error == null && recentActivity.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'No recent activity',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
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
                children: suspendedDriversPreview.take(3).map((d) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_off, size: 20, color: Colors.red),
                  title: Text(d['name'] ?? 'Unknown Driver'),
                  subtitle: Text(
                    'Reason: ${d['reason'] ?? 'Not specified'}',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.info_outline, size: 18),
                    onPressed: () => Navigator.pushNamed(context, '/admin/users'),
                  ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // For small screens, show buttons in a wrapped grid
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _quickActionButton('Add Driver', Icons.person_add, '/admin/users'),
              _quickActionButton('Fleet Management', Icons.directions_bus, '/admin/shuttles'),
              _quickActionButton('Send Notification', Icons.send, '/admin/notifications'),
              _quickActionButton('View Complaints', Icons.report, '/admin/complaints'),
              _quickActionButton('Manage Schedules', Icons.schedule, '/admin/schedules'),
            ],
          );
        }
        // For wider screens, keep the horizontal row
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _quickActionButton('Add Driver', Icons.person_add, '/admin/users'),
              const SizedBox(width: 8),
              _quickActionButton('Fleet Management', Icons.directions_bus, '/admin/shuttles'),
              const SizedBox(width: 8),
              _quickActionButton('Send Notification', Icons.send, '/admin/notifications'),
              const SizedBox(width: 8),
              _quickActionButton('View Complaints', Icons.report, '/admin/complaints'),
              const SizedBox(width: 8),
              _quickActionButton('Manage Schedules', Icons.schedule, '/admin/schedules'),
            ],
          ),
        );
      },
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
        automaticallyImplyLeading: false,
        title: Text(_isLoadingName ? 'Admin Dashboard' : 'Hi, ${_displayName}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Schedule...'),
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
}
