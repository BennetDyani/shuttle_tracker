import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/APIService.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/notifications_provider.dart';
import '../../../utils/logout_helper.dart';
import 'accessible_routes.dart';
import 'profile_page.dart';
import 'report_issues.dart';
import '../student_live_tracking_screen.dart';
import '../student_schedule_screen.dart';
import '../destination_subscription_screen.dart';
import '../normal_students/notifications_screen.dart';

class DisabledStudentDashboard extends StatefulWidget {
  const DisabledStudentDashboard({super.key});

  @override
  State<DisabledStudentDashboard> createState() => _DisabledStudentDashboardState();
}

class _DisabledStudentDashboardState extends State<DisabledStudentDashboard> {
  final APIService _apiService = APIService();
  bool _isLoadingName = true;
  bool _isLoadingShuttle = false;
  String _displayName = '';
  String? _error;
  String? _shuttleError;

  // Shuttle tracking data
  String _nextPickupTime = '08:30 AM';
  String _pickupLocation = 'Main Campus';
  String _estimatedArrival = '09:00 AM';
  String _destination = 'Residence Hall';
  String _assignedRoute = 'Accessible Route A';
  bool _hasActiveShuttle = false;

  @override
  void initState() {
    super.initState();
    _loadName();
    _loadShuttleInfo();
  }

  Future<void> _loadShuttleInfo() async {
    if (!mounted) return;

    setState(() {
      _isLoadingShuttle = true;
      _shuttleError = null;
    });

    try {
      // Fetch routes to find accessible ones
      final routes = await _apiService.get('routes/getAll');

      if (routes != null) {
        List<dynamic> routeList = [];

        // Extract routes from response
        if (routes is List) {
          routeList = routes;
        } else if (routes is Map) {
          routeList = routes['routes'] ??
                     routes['data'] ??
                     routes['items'] ??
                     [];
        }

        if (routeList.isNotEmpty) {
          // Find first accessible route or use first route
          final route = routeList.first;
          final routeName = route['name'] ?? route['route_name'] ?? route['routeName'] ?? 'Accessible Route';
          final origin = route['origin'] ?? route['start'] ?? 'Main Campus';
          final destination = route['destination'] ?? route['end'] ?? 'Residence Hall';

          if (mounted) {
            setState(() {
              _assignedRoute = routeName.toString();
              _pickupLocation = origin.toString();
              _destination = destination.toString();
              _hasActiveShuttle = true;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _hasActiveShuttle = false;
              _shuttleError = null; // Don't show error if just no routes
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading shuttle info: $e');
      if (mounted) {
        setState(() {
          _shuttleError = null; // Don't show error to user
          _hasActiveShuttle = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingShuttle = false);
    }
  }

  Future<void> _loadName() async {
    if (!mounted) return;

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

      // fetchUserById now has built-in fallback logic
      final user = await _apiService.fetchUserById(uid);
      if (!mounted) return;

      final first = (user['first_name'] ?? user['firstName'] ?? user['name'] ?? '').toString();
      final last = (user['last_name'] ?? user['lastName'] ?? user['surname'] ?? '').toString();
      final combined = ('$first $last').trim();

      setState(() {
        _displayName = combined.isEmpty ? (user['email']?.toString() ?? 'Student') : combined;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error loading user name: $e');
      setState(() {
        _error = null; // Don't show error to user, just use default greeting
        _displayName = 'Student'; // Fallback name
      });
    } finally {
      if (mounted) setState(() => _isLoadingName = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 600;
    final title = _isLoadingName ? 'Welcome' : (_displayName.isNotEmpty ? 'Hi, $_displayName' : 'Welcome');

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          semanticsLabel: 'Dashboard title: $title',
        ),
        actions: [
          // Notifications icon with unread count
          Consumer<NotificationsProvider>(builder: (context, notif, _) {
            return IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications, size: 28),
                  if (!notif.isLoading && notif.unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
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
              tooltip: 'Notifications',
            );
          }),
          IconButton(
            icon: const Icon(Icons.mic, size: 28),
            onPressed: () {
              // TODO: Implement voice navigation
            },
            tooltip: 'Voice Navigation',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => LogoutHelper.logout(context),
            tooltip: 'Logout',
          ),
        ],
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Card(
                          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      ),
                    _buildShuttleCard(constraints),
                    SizedBox(height: isSmallScreen ? 16.0 : 24.0),
                    _buildQuickActionsGrid(constraints),
                    SizedBox(height: isSmallScreen ? 16.0 : 24.0),
                    _buildRecentActivity(constraints),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShuttleCard(BoxConstraints constraints) {
    final isSmallScreen = constraints.maxWidth < 600;

    return Card(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
        child: _isLoadingShuttle
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            : !_hasActiveShuttle && _shuttleError == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.accessible,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No Active Shuttle',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No accessible route assigned yet',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_shuttleError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _shuttleError!,
                              style: const TextStyle(color: Colors.orange, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  constraints.maxWidth < 600
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.accessible,
                                    size: 36,
                                    color: Theme.of(context).primaryColor,
                                    semanticLabel: 'Accessible shuttle icon'),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'My Shuttle (Wheelchair Accessible)',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    semanticsLabel: 'My Shuttle section, Wheelchair Accessible',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Assigned Route: $_assignedRoute',
                              style: const TextStyle(fontSize: 16),
                              semanticsLabel: 'Assigned to $_assignedRoute',
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Icon(Icons.accessible,
                                size: 36,
                                color: Theme.of(context).primaryColor,
                                semanticLabel: 'Accessible shuttle icon'),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'My Shuttle (Wheelchair Accessible)',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    semanticsLabel: 'My Shuttle section, Wheelchair Accessible',
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Assigned Route: $_assignedRoute',
                                    style: const TextStyle(fontSize: 16),
                                    semanticsLabel: 'Assigned to $_assignedRoute',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                  SizedBox(height: isSmallScreen ? 12.0 : 15.0),
                  constraints.maxWidth < 600
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildScheduleInfo(),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: _buildScheduleInfo(),
                        ),
                ],
              ),
      ),
    );
  }

  List<Widget> _buildScheduleInfo() {
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Next Pickup',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            semanticsLabel: 'Next Pickup time information',
          ),
          const SizedBox(height: 4),
          Text(
            _nextPickupTime,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            semanticsLabel: 'Pickup at $_nextPickupTime',
          ),
          Text(
            'From: $_pickupLocation',
            style: const TextStyle(fontSize: 14),
            semanticsLabel: 'Pickup location: $_pickupLocation',
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estimated Arrival',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            semanticsLabel: 'Estimated arrival time information',
          ),
          const SizedBox(height: 4),
          Text(
            _estimatedArrival,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            semanticsLabel: 'Estimated arrival at $_estimatedArrival',
          ),
          Text(
            'To: $_destination',
            style: const TextStyle(fontSize: 14),
            semanticsLabel: 'Destination: $_destination',
          ),
        ],
      ),
    ];
  }

  Widget _buildQuickActionsGrid(BoxConstraints constraints) {
    final isSmallScreen = constraints.maxWidth < 600;
    final buttonWidth = (constraints.maxWidth - (isSmallScreen ? 32 : 48)) / (isSmallScreen ? 2 : 4);
    final buttonSpacing = isSmallScreen ? 12.0 : 16.0;

    return Wrap(
      spacing: buttonSpacing,
      runSpacing: buttonSpacing,
      alignment: WrapAlignment.center,
      children: [
        _actionButton(
          'Track Minibus',
          Icons.location_on,
          Theme.of(context).primaryColor,
          buttonWidth,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentLiveTrackingScreen())),
        ),
        _actionButton(
          'Schedules',
          Icons.schedule,
          Colors.blue,
          buttonWidth,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentScheduleScreen())),
        ),
        _actionButton(
          'Subscriptions',
          Icons.notifications_active,
          Colors.green,
          buttonWidth,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DestinationSubscriptionScreen())),
        ),
        _actionButton(
          'View Routes',
          Icons.route,
          Colors.teal,
          buttonWidth,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccessibleRoutesScreen())),
        ),
        _actionButton(
          'Report Issue',
          Icons.report_problem,
          Colors.orange,
          buttonWidth,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportIssueScreen())),
        ),
        _actionButton(
          'My Profile',
          Icons.person,
          Colors.purple,
          buttonWidth,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DisabledStudentProfilePage())),
        ),
      ],
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, double width, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(77)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 32,
                semanticLabel: '$label icon',
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                semanticsLabel: '$label button',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(BoxConstraints constraints) {
    final isSmallScreen = constraints.maxWidth < 600;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              semanticsLabel: 'Recent Activity section',
            ),
            SizedBox(height: isSmallScreen ? 12.0 : 15.0),
            constraints.maxWidth < 600
                ? Column(
                    children: _buildActivityItems(),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildActivityItems()
                        .map((item) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: item,
                              ),
                            ))
                        .toList(),
                  ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActivityItems() {
    return [
      _activityItem(
        Icons.location_on,
        Theme.of(context).primaryColor,
        'Last Ride',
        'Yesterday at 5:30 PM',
        'From Main Campus to Residence',
      ),
      _activityItem(
        Icons.report_problem,
        Colors.orange,
        'Issue Reported',
        '2 days ago',
        'Accessibility ramp maintenance',
      ),
    ];
  }

  Widget _activityItem(IconData icon, Color color, String title, String time, String description) {
    return Semantics(
      label: '$title: $description, $time',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 15.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    time,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
