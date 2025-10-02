import 'package:flutter/material.dart';
import '../../models/user.dart';

import '../../models/disabled_student.dart';

class StudentDashboard extends StatefulWidget {
  final User? user;
  final DisabledStudent? disabledStudent;

  const StudentDashboard({
    Key? key,
    this.user,
    this.disabledStudent,
  }) : super(key: key);

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0; // 0=Home, 1=Shuttles, 2=Alerts, 3=Profile
  bool _rampAssistanceRequested = false;
  bool _priorityBoardingRequested = false;
  bool _escortServiceRequested = false;
  bool _driverNotified = false;

  @override
  Widget build(BuildContext context) {
    // If disabled student data is provided, show disabled dashboard content
    if (widget.disabledStudent != null && widget.user != null) {
      return _buildDisabledStudentDashboard();
    }

    // Otherwise show regular student dashboard
    return _buildRegularStudentDashboard();
  }

  Widget _buildDisabledStudentDashboard() {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Accessibility Services'),
        backgroundColor: Colors.green[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.emergency),
            onPressed: _showEmergencyOptions,
            tooltip: 'Emergency Assistance',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _buildCurrentScreen(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildRegularStudentDashboard() {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("HomePage"),
        backgroundColor: Colors.blue[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _buildCurrentScreen(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // BOTTOM NAVIGATION BAR
  BottomNavigationBar _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue[800],
      unselectedItemColor: Colors.grey[600],
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.directions_bus),
          label: 'Shuttles',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications),
          label: 'Alerts',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  Widget _buildCurrentScreen() {
    // Different content for disabled vs regular students
    if (widget.disabledStudent != null && widget.user != null) {
      return _buildDisabledCurrentScreen();
    } else {
      return _buildRegularCurrentScreen();
    }
  }

  // DISABLED STUDENT SCREENS
  Widget _buildDisabledCurrentScreen() {
    switch (_currentIndex) {
      case 0: // Home
        return _buildDisabledHomeScreen();
      case 1: // Shuttles
        return _buildDisabledShuttleScreen();
      case 2: // Alerts
        return _buildDisabledAlertsScreen();
      case 3: // Profile
        return _buildDisabledProfileScreen();
      default:
        return _buildDisabledHomeScreen();
    }
  }

  // ENHANCED DISABLED HOME SCREEN
  Widget _buildDisabledHomeScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Welcome Card with Accessibility Status
        _buildDisabledWelcomeCard(),
        const SizedBox(height: 20),

        // Next Accessible Shuttle
        _buildNextAccessibleShuttleCard(),
        const SizedBox(height: 20),

        // Quick Assistance Buttons
        _buildQuickAssistanceCard(),
        const SizedBox(height: 20),

        // Campus Accessibility Status
        _buildCampusAccessibilityStatus(),
        const SizedBox(height: 20),

        // Accessibility Features Status
        _buildAccessibilityFeaturesCard(),
        const SizedBox(height: 20),

        // Emergency Quick Access
        _buildEmergencyQuickAccess(),
      ],
    );
  }

  Widget _buildDisabledShuttleScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '🚌 Accessible Shuttle Schedule',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _buildAccessibleShuttleCard('Campus Express', '08:00 AM', 'Platform 1', true, true, true),
        _buildAccessibleShuttleCard('Main Line', '09:30 AM', 'Platform 2', true, false, true),
        _buildAccessibleShuttleCard('Residence Shuttle', '11:00 AM', 'Platform 3', false, true, false),
        _buildAccessibleShuttleCard('Evening Service', '05:00 PM', 'Platform 1', true, true, true),
      ],
    );
  }

  Widget _buildDisabledAlertsScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '⚠️ Accessibility Alerts',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _buildAlertCard('Elevator Maintenance', 'Science Building elevator out of service until Friday', Icons.warning, Colors.orange),
        _buildAlertCard('Ramp Available', 'All shuttles now equipped with ramps', Icons.check_circle, Colors.green),
        _buildAlertCard('Pathway Closure', 'Main pathway to library temporarily closed for repairs', Icons.block, Colors.orange),
        _buildAlertCard('Weather Alert', 'Heavy rain expected today, allow extra travel time', Icons.cloud, Colors.blue),
        _buildAlertCard('New Accessible Van', 'New wheelchair accessible van added to fleet', Icons.directions_bus, Colors.green),
      ],
    );
  }

  Widget _buildDisabledProfileScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '👤 Your Accessibility Profile',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _buildDisabledWelcomeCard(),
        const SizedBox(height: 20),
        _buildAccessibilityNeedsCard(),
        const SizedBox(height: 20),
        _buildEmergencyContactsCard(),
        const SizedBox(height: 20),
        _buildAccessibilityPreferences(),
      ],
    );
  }

  // REGULAR STUDENT SCREENS
  Widget _buildRegularCurrentScreen() {
    switch (_currentIndex) {
      case 0: // Home
        return _buildRegularHomeScreen();
      case 1: // Shuttles
        return _buildRegularShuttleScreen();
      case 2: // Alerts
        return _buildRegularAlertsScreen();
      case 3: // Profile
        return _buildRegularProfileScreen();
      default:
        return _buildRegularHomeScreen();
    }
  }

  Widget _buildRegularHomeScreen() {
    return Container(
      color: Colors.grey[200],
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildNextShuttleCard(
            timeToArrival: "Arriving in 5 min",
            route: "Route 1A",
            platform: "Platform 3",
          ),
          const SizedBox(height: 20),
          _buildMiddleNavigationTabs(),
          const SizedBox(height: 20),
          _buildNearbyShuttlesSection(),
          const SizedBox(height: 20),
          _buildRecentRoutesSection(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // NEW METHODS FOR DISABLED STUDENT DASHBOARD

  Widget _buildNextAccessibleShuttleCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.accessible, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Next Accessible Shuttle',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Arriving in 8 min',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 8),
            const Text('Route 2B • Platform 1'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildFeatureChip('Wheelchair Ramp', Icons.ramp_right),
                _buildFeatureChip('Priority Seating', Icons.event_seat),
                _buildFeatureChip('Audio Announcements', Icons.volume_up),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                foregroundColor: Colors.white,
              ),
              child: const Text('Track Shuttle Location'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label, IconData icon) {
    return Chip(
      label: Text(label),
      avatar: Icon(icon, size: 16),
      backgroundColor: Colors.green[50],
      labelStyle: const TextStyle(fontSize: 12),
    );
  }

  Widget _buildCampusAccessibilityStatus() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🏛️ Campus Accessibility Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildAccessibilityStatusItem('Library', 'Fully Accessible', Icons.check_circle, Colors.green),
            _buildAccessibilityStatusItem('Science Building', 'Elevator Maintenance', Icons.warning, Colors.orange),
            _buildAccessibilityStatusItem('Cafeteria', 'Ramp Available', Icons.check_circle, Colors.green),
            _buildAccessibilityStatusItem('Sports Complex', 'Limited Accessibility', Icons.info, Colors.blue),
            _buildAccessibilityStatusItem('Admin Building', 'Fully Accessible', Icons.check_circle, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessibilityStatusItem(String location, String status, IconData icon, Color color) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(location, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(status),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // Navigate to building accessibility details
      },
    );
  }

  Widget _buildEmergencyQuickAccess() {
    return Card(
      elevation: 4,
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🆘 Emergency Quick Access',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 12),
            const Text(
              'Immediate assistance for urgent needs',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildEmergencyButton('Medical', Icons.medical_services, Colors.red),
                _buildEmergencyButton('Security', Icons.security, Colors.orange),
                _buildEmergencyButton('Transport', Icons.directions_bus, Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyButton(String label, IconData icon, Color color) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color,
          radius: 24,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  Widget _buildAccessibleShuttleCard(String route, String time, String platform, bool hasRamp, bool hasPrioritySeating, bool hasAudioAnnouncements) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_bus,
                  color: hasRamp ? Colors.green : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text('Time: $time • $platform'),
                    ],
                  ),
                ),
                Icon(
                  hasRamp ? Icons.check_circle : Icons.error,
                  color: hasRamp ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (hasRamp) _buildFeatureChip('Ramp', Icons.ramp_right),
                if (hasPrioritySeating) _buildFeatureChip('Priority Seating', Icons.event_seat),
                if (hasAudioAnnouncements) _buildFeatureChip('Audio', Icons.volume_up),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessibilityNeedsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '♿ Your Accessibility Needs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (widget.disabledStudent!.accessNeeds.isNotEmpty)
              Text(
                'Special Requirements: ${widget.disabledStudent!.accessNeeds}',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
            const SizedBox(height: 12),
            const Text(
              'Preferred Assistance:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Ramp Assistance'),
                  selected: _rampAssistanceRequested,
                  onSelected: (value) {
                    setState(() {
                      _rampAssistanceRequested = value;
                    });
                  },
                ),
                FilterChip(
                  label: const Text('Priority Boarding'),
                  selected: _priorityBoardingRequested,
                  onSelected: (value) {
                    setState(() {
                      _priorityBoardingRequested = value;
                    });
                  },
                ),
                FilterChip(
                  label: const Text('Escort Service'),
                  selected: _escortServiceRequested,
                  onSelected: (value) {
                    setState(() {
                      _escortServiceRequested = value;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessibilityPreferences() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚙️ Accessibility Preferences',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Notify Drivers of Special Needs'),
              value: _driverNotified,
              onChanged: (value) {
                setState(() {
                  _driverNotified = value;
                });
              },
              activeColor: Colors.green[800],
            ),
            const SwitchListTile(
              title: Text('High Contrast Mode'),
              value: true,
              onChanged: null,
            ),
            const SwitchListTile(
              title: Text('Text-to-Speech Announcements'),
              value: true,
              onChanged: null,
            ),
            const SwitchListTile(
              title: Text('Vibration Alerts'),
              value: false,
              onChanged: null,
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced Quick Assistance Card with more options
  Widget _buildQuickAssistanceCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🚨 Quick Assistance Request',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            _buildAssistanceButton(
              'Request Ramp Assistance',
              Icons.ramp_right,
              _rampAssistanceRequested,
              _requestRampAssistance,
            ),
            const SizedBox(height: 10),
            _buildAssistanceButton(
              'Priority Boarding',
              Icons.accessible_forward,
              _priorityBoardingRequested,
              _requestPriorityBoarding,
            ),
            const SizedBox(height: 10),
            _buildAssistanceButton(
              'Request Escort Service',
              Icons.directions_walk,
              _escortServiceRequested,
              _requestEscortService,
            ),
            const SizedBox(height: 10),
            _buildAssistanceButton(
              'Notify Driver of Special Needs',
              Icons.notification_important,
              _driverNotified,
              _notifyDriver,
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced Accessibility Features Card
  Widget _buildAccessibilityFeaturesCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '♿ Available Accessibility Features',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            _buildFeatureStatus('Wheelchair Accessible Shuttles', true, 'All main routes'),
            _buildFeatureStatus('Priority Seating', true, 'Reserved front seating'),
            _buildFeatureStatus('Audio Announcements', true, 'Next stop alerts'),
            _buildFeatureStatus('Visual Indicators', true, 'LED signage'),
            _buildFeatureStatus('Kneeling Buses', false, 'Available Oct 2025'),
            _buildFeatureStatus('Braille Signage', true, 'All shuttle entrances'),
          ],
        ),
      ),
    );
  }

  // Update the existing _buildFeatureStatus to include optional description
  Widget _buildFeatureStatus(String feature, bool available, [String description = '']) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        available ? Icons.check_circle : Icons.error,
        color: available ? Colors.green : Colors.grey,
      ),
      title: Text(feature),
      subtitle: description.isNotEmpty ? Text(description) : null,
      trailing: Text(
        available ? 'Available' : 'Coming Soon',
        style: TextStyle(
          color: available ? Colors.green : Colors.grey,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // New assistance request methods
  void _requestEscortService() {
    setState(() => _escortServiceRequested = !_escortServiceRequested);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_escortServiceRequested
          ? 'Campus security escort requested'
          : 'Escort service cancelled')),
    );
  }

  void _notifyDriver() {
    setState(() => _driverNotified = !_driverNotified);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_driverNotified
          ? 'Driver has been notified of your needs'
          : 'Driver notification cancelled')),
    );
  }

  // REGULAR STUDENT DASHBOARD COMPONENTS (keep your existing methods)

  Widget _buildNextShuttleCard({required String timeToArrival, required String route, required String platform}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Next Shuttle',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              timeToArrival,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              route,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              platform,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiddleNavigationTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildNavTab('Map', Icons.map),
        _buildNavTab('Favorites', Icons.favorite_border),
        _buildNavTab('History', Icons.history),
        _buildNavTab('Tickets', Icons.confirmation_number_outlined),
      ],
    );
  }

  Widget _buildNavTab(String label, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 28, color: Colors.blue[800]),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.blue[800]),
        ),
      ],
    );
  }

  Widget _buildNearbyShuttlesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nearby Shuttles',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildShuttleListItem('Route 2B', '8 min', '2KM away'),
        _buildShuttleListItem('Route 3A', '15 min', '4KM away'),
      ],
    );
  }

  Widget _buildShuttleListItem(String route, String time, String distance) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue[800],
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.directions_bus, color: Colors.white, size: 20),
      ),
      title: Text(
        route,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('$time • $distance'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }

  Widget _buildRecentRoutesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Routes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildRecentRouteItem('Beliville Campus → District 6 Campus', 'Today, 9:30 AM'),
        _buildRecentRouteItem('District 6 Campus → Mowbray Campus', 'Yesterday, 2:15 PM'),
      ],
    );
  }

  Widget _buildRecentRouteItem(String route, String time) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.route, color: Colors.grey[700], size: 20),
      ),
      title: Text(
        route,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(time),
    );
  }

  Widget _buildRegularShuttleScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '🚌 Shuttle Schedule',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _buildShuttleCard('Campus Express', '08:00 AM', 'Express Service', true),
        _buildShuttleCard('Main Line', '09:30 AM', 'All Stops', true),
        _buildShuttleCard('Residence Shuttle', '11:00 AM', 'Residence Areas', true),
        _buildShuttleCard('Evening Service', '05:00 PM', 'Late Service', true),
      ],
    );
  }

  Widget _buildRegularAlertsScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '📢 Alerts & Notifications',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _buildAlertCard('Schedule Change', 'Shuttle times updated for finals week', Icons.info, Colors.blue),
        _buildAlertCard('Weather Alert', 'Heavy rain expected today', Icons.cloud, Colors.blue),
        _buildAlertCard('Maintenance', 'Shuttle #5 undergoing maintenance', Icons.build, Colors.orange),
      ],
    );
  }

  Widget _buildRegularProfileScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.blue[800],
            child: Text(
              widget.user != null
                  ? '${widget.user!.name[0]}${widget.user!.surname[0]}'
                  : 'JD',
              style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.user != null
                ? '${widget.user!.name} ${widget.user!.surname}'
                : 'Student User',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Text(
            widget.user != null ? widget.user!.userType : 'Student',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          const Text(
            'Personal Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildInfoCard('Email', widget.user?.email ?? 'Not available'),
          const SizedBox(height: 12),
          _buildInfoCard('Password', '••••••••', isPassword: true),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.lock_reset),
            label: const Text('Change Password'),
            onPressed: _changePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'App Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSettingSwitch('Notifications', 'Receive shuttle updates', true, (value) {}),
          _buildSettingSwitch('Dark Mode', 'Use dark theme', false, (value) {}),
          _buildSettingSwitch('Location Services', 'Allow location access', true, (value) {}),
          const SizedBox(height: 30),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Log Out'),
            onPressed: _logout,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // COMMON WIDGETS

  Widget _buildDisabledWelcomeCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${widget.user!.name}! 👋',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Disability Type: ${_formatDisabilityType(widget.disabledStudent!.disabilityType)}',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            if (widget.disabledStudent!.accessNeeds.isNotEmpty)
              Text(
                'Special Requirements: ${widget.disabledStudent!.accessNeeds}',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShuttleCard(String route, String time, String features, bool isActive) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: ListTile(
        leading: Icon(
          Icons.directions_bus,
          color: isActive ? Colors.green : Colors.grey,
          size: 32,
        ),
        title: Text(
          route,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time: $time'),
            Text('Features: $features'),
          ],
        ),
        trailing: Icon(
          isActive ? Icons.check_circle : Icons.error,
          color: isActive ? Colors.green : Colors.orange,
        ),
      ),
    );
  }

  Widget _buildAlertCard(String title, String message, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(message),
        trailing: const Icon(Icons.arrow_forward),
      ),
    );
  }

  Widget _buildAssistanceButton(String text, IconData icon, bool isActive, VoidCallback onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(text),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.green : Colors.blue[800],
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }

  Widget _buildEmergencyContactsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📞 Emergency Contacts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            _buildContactTile('Campus Security', '021 123 4567', Icons.security),
            _buildContactTile('Disability Unit', '021 123 4568', Icons.accessible),
            _buildContactTile('Transport Office', '021 123 4569', Icons.directions_bus),
            _buildContactTile('Medical Emergency', '021 123 4570', Icons.medical_services),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile(String name, String number, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.green[800]),
      title: Text(name),
      subtitle: Text(number),
      trailing: IconButton(
        icon: const Icon(Icons.call, color: Colors.green),
        onPressed: () => _makeCall(number),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, {bool isPassword = false}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingSwitch(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.blue[800],
    );
  }

  // Helper methods
  String _formatDisabilityType(String type) {
    switch (type) {
      case 'physical': return 'Physical Disability';
      case 'visual': return 'Visual Impairment';
      case 'hearing': return 'Hearing Impairment';
      case 'other': return 'Other Disability';
      default: return type;
    }
  }

  void _requestRampAssistance() {
    setState(() => _rampAssistanceRequested = !_rampAssistanceRequested);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_rampAssistanceRequested
            ? 'Ramp assistance requested'
            : 'Ramp assistance cancelled'),
      ),
    );
  }

  void _requestPriorityBoarding() {
    setState(() => _priorityBoardingRequested = !_priorityBoardingRequested);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_priorityBoardingRequested
            ? 'Priority boarding requested'
            : 'Priority boarding cancelled'),
      ),
    );
  }

  void _showEmergencyOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Assistance'),
        content: const Text('What type of emergency assistance do you need?'),
        actions: [
          TextButton(
            onPressed: () => _makeCall('112'),
            child: const Text('Medical Emergency'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _makeCall(String number) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Calling $number...')),
    );
  }

  void _changePassword() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password changed successfully')),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800]),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    Navigator.pushReplacementNamed(context, '/login');
  }
}

// import 'package:flutter/material.dart';
// import '../../models/user.dart';
// import '../../models/disabled_student.dart';
//
// class StudentDashboard extends StatefulWidget {
//   final User? user;
//   final DisabledStudent? disabledStudent;
//
//   const StudentDashboard({
//     Key? key,
//     this.user,
//     this.disabledStudent,
//   }) : super(key: key);
//
//   @override
//   _StudentDashboardState createState() => _StudentDashboardState();
// }
//
// class _StudentDashboardState extends State<StudentDashboard> {
//   int _currentIndex = 0; // 0=Home, 1=Shuttles, 2=Alerts, 3=Profile
//   bool _rampAssistanceRequested = false;
//   bool _priorityBoardingRequested = false;
//
//   @override
//   Widget build(BuildContext context) {
//     // If disabled student data is provided, show disabled dashboard content
//     if (widget.disabledStudent != null && widget.user != null) {
//       return _buildDisabledStudentDashboard();
//     }
//
//     // Otherwise show regular student dashboard
//     return _buildRegularStudentDashboard();
//   }
//
//   Widget _buildDisabledStudentDashboard() {
//     return Scaffold(
//       backgroundColor: Colors.grey[100],
//       appBar: AppBar(
//         title: const Text('Accessibility Services'),
//         backgroundColor: Colors.green[800],
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.emergency),
//             onPressed: _showEmergencyOptions,
//             tooltip: 'Emergency Assistance',
//           ),
//           IconButton(
//             icon: const Icon(Icons.logout),
//             onPressed: _logout,
//             tooltip: 'Logout',
//           ),
//         ],
//       ),
//       body: _buildCurrentScreen(),
//       bottomNavigationBar: _buildBottomNavigationBar(),
//     );
//   }
//
//   Widget _buildRegularStudentDashboard() {
//     return Scaffold(
//       backgroundColor: Colors.grey[100], // Or the new Colors.grey[200] if you prefer
//       appBar: AppBar(
//         // title: Text( // Your OLD title
//         //     widget.user != null
//         //         ? 'Welcome, ${widget.user!.name}!'
//         //         : 'Student Dashboard'
//         // ),
//         title: const Text("HomePage"), // NEW title as per design
//         backgroundColor: Colors.blue[900], // Keep or change as per your new design's primary color
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.logout),
//             onPressed: _logout,
//             tooltip: 'Logout', // Good practice to add tooltips
//           ),
//         ],
//       ),
//       body: _buildCurrentScreen(), // This will now correctly call the new home screen
//       bottomNavigationBar: _buildBottomNavigationBar(),
//     );
//   }
//
//   // Widget _buildRegularStudentDashboard() {
//   //   return Scaffold(
//   //     appBar: AppBar(
//   //       title: Text(
//   //           widget.user != null
//   //               ? 'Welcome, ${widget.user!.name}!'
//   //               : 'Student Dashboard'
//   //       ),
//   //       backgroundColor: Colors.blue[900],
//   //       actions: [
//   //         IconButton(
//   //           icon: const Icon(Icons.logout),
//   //           onPressed: _logout,
//   //         ),
//   //       ],
//   //     ),
//   //     body: _buildCurrentScreen(),
//   //     bottomNavigationBar: _buildBottomNavigationBar(),
//   //   );
//   // }
//
//   // BOTTOM NAVIGATION BAR
//   BottomNavigationBar _buildBottomNavigationBar() {
//     return BottomNavigationBar(
//       currentIndex: _currentIndex,
//       onTap: (index) => setState(() => _currentIndex = index),
//       type: BottomNavigationBarType.fixed,
//       selectedItemColor: Colors.blue[800],
//       unselectedItemColor: Colors.grey[600],
//       items: const [
//         BottomNavigationBarItem(
//           icon: Icon(Icons.home),
//           label: 'Home',
//         ),
//         BottomNavigationBarItem(
//           icon: Icon(Icons.directions_bus),
//           label: 'Shuttles',
//         ),
//         BottomNavigationBarItem(
//           icon: Icon(Icons.notifications),
//           label: 'Alerts',
//         ),
//         BottomNavigationBarItem(
//           icon: Icon(Icons.person),
//           label: 'Profile',
//         ),
//       ],
//     );
//   }
//
//   Widget _buildCurrentScreen() {
//     // Different content for disabled vs regular students
//     if (widget.disabledStudent != null && widget.user != null) {
//       return _buildDisabledCurrentScreen();
//     } else {
//       return _buildRegularCurrentScreen();
//     }
//   }
//
//   // DISABLED STUDENT SCREENS
//   Widget _buildDisabledCurrentScreen() {
//     switch (_currentIndex) {
//       case 0: // Home
//         return _buildDisabledHomeScreen();
//       case 1: // Shuttles
//         return _buildDisabledShuttleScreen();
//       case 2: // Alerts
//         return _buildDisabledAlertsScreen();
//       case 3: // Profile
//         return _buildDisabledProfileScreen();
//       default:
//         return _buildDisabledHomeScreen();
//     }
//   }
//
//   Widget _buildDisabledHomeScreen() {
//     return ListView(
//       padding: const EdgeInsets.all(16),
//       children: [
//         _buildDisabledWelcomeCard(),
//         const SizedBox(height: 20),
//         _buildQuickAssistanceCard(),
//         const SizedBox(height: 20),
//         _buildAccessibilityFeaturesCard(),
//       ],
//     );
//   }
//
//   Widget _buildDisabledShuttleScreen() {
//     return ListView(
//       padding: const EdgeInsets.all(16),
//       children: [
//         const Text(
//           '🚌 Accessible Shuttle Schedule',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//           textAlign: TextAlign.center,
//         ),
//         const SizedBox(height: 20),
//         _buildShuttleCard('Campus Express', '08:00 AM', 'Has Ramp', true),
//         _buildShuttleCard('Main Line', '09:30 AM', 'Wheelchair Space', true),
//         _buildShuttleCard('Residence Shuttle', '11:00 AM', 'No Ramp', false),
//         _buildShuttleCard('Evening Service', '05:00 PM', 'Has Ramp', true),
//       ],
//     );
//   }
//
//   Widget _buildDisabledAlertsScreen() {
//     return ListView(
//       padding: const EdgeInsets.all(16),
//       children: [
//         const Text(
//           '⚠️ Accessibility Alerts',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//           textAlign: TextAlign.center,
//         ),
//         const SizedBox(height: 20),
//         _buildAlertCard('Elevator Maintenance', 'Science Building elevator out of service until Friday', Icons.warning, Colors.orange),
//         _buildAlertCard('Ramp Available', 'All shuttles now equipped with ramps', Icons.check_circle, Colors.green),
//         _buildAlertCard('Weather Alert', 'Heavy rain expected today, allow extra travel time', Icons.cloud, Colors.blue),
//       ],
//     );
//   }
//
//   Widget _buildDisabledProfileScreen() {
//     return ListView(
//       padding: const EdgeInsets.all(16),
//       children: [
//         const Text(
//           '👤 Your Profile',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//           textAlign: TextAlign.center,
//         ),
//         const SizedBox(height: 20),
//         _buildDisabledWelcomeCard(),
//         const SizedBox(height: 20),
//         _buildEmergencyContactsCard(),
//       ],
//     );
//   }
//
//   // REGULAR STUDENT SCREENS
//   Widget _buildRegularCurrentScreen() {
//     switch (_currentIndex) {
//       case 0: // Home
//         return _buildRegularHomeScreen();
//       case 1: // Shuttles
//         return _buildRegularShuttleScreen();
//       case 2: // Alerts
//         return _buildRegularAlertsScreen();
//       case 3: // Profile
//         return _buildRegularProfileScreen();
//       default:
//         return _buildRegularHomeScreen();
//     }
//   }
//
//   // Widget _buildRegularHomeScreen() {
//   //   return const Center(
//   //     child: Text(
//   //       'Welcome to Student Dashboard!\n\nUse the bottom navigation to access:\n• Shuttle Schedules\n• Alerts & Notifications\n• Your Profile',
//   //       style: TextStyle(fontSize: 18),
//   //       textAlign: TextAlign.center,
//   //     ),
//   //   );
//   // }
//
//   Widget _buildRegularHomeScreen() {
//     // Use a light grey background for the whole screen if desired,
//     // or set it on the Scaffold if you want it app-wide for regular users.
//     return Container(
//       color: Colors.grey[200], // Example light grey background
//       child: ListView( // Use ListView for scrollability
//         padding: const EdgeInsets.all(16.0),
//         children: [
//           // Top Section: User Welcome (already handled by AppBar, but if you need it in the body)
//           // _buildWelcomeHeader("John D."), // You can get user's name from widget.user!.name
//
//           // Main "Next Shuttle" Information Card
//           _buildNextShuttleCard(
//             timeToArrival: "Arriving in 5 min",
//             route: "Route 1A",
//             platform: "Platform 3",
//           ),
//           const SizedBox(height: 20),
//
//           // Middle Navigation Tabs
//           _buildMiddleNavigationTabs(),
//           const SizedBox(height: 20),
//
//           // "Nearby Shuttles" List Section
//           _buildNearbyShuttlesSection(),
//           const SizedBox(height: 20),
//
//           // "Recent Routes" List Section
//           _buildRecentRoutesSection(),
//           const SizedBox(height: 16), // Adjust spacing as needed
//         ],
//       ),
//     );
//   }
//
//   // NEW METHODS FOR THE REGULAR HOME SCREEN
//
//   Widget _buildNextShuttleCard({required String timeToArrival, required String route, required String platform}) {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: const EdgeInsets.all(20.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Next Shuttle',
//               style: TextStyle(fontSize: 16, color: Colors.grey),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               timeToArrival,
//               style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 16),
//             Text(
//               route,
//               style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
//             ),
//             const SizedBox(height: 4),
//             Text(
//               platform,
//               style: TextStyle(fontSize: 16, color: Colors.grey[700]),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildMiddleNavigationTabs() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceAround,
//       children: [
//         _buildNavTab('Map', Icons.map),
//         _buildNavTab('Favorites', Icons.favorite_border),
//         _buildNavTab('History', Icons.history),
//         _buildNavTab('Tickets', Icons.confirmation_number_outlined),
//       ],
//     );
//   }
//
//   Widget _buildNavTab(String label, IconData icon) {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Icon(icon, size: 28, color: Colors.blue[800]),
//         const SizedBox(height: 4),
//         Text(
//           label,
//           style: TextStyle(fontSize: 12, color: Colors.blue[800]),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildNearbyShuttlesSection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'Nearby Shuttles',
//           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//         ),
//         const SizedBox(height: 12),
//         _buildShuttleListItem('Route 2B', '8 min', '2KM away'),
//         _buildShuttleListItem('Route 3A', '15 min', '4KM away'),
//       ],
//     );
//   }
//
//   Widget _buildShuttleListItem(String route, String time, String distance) {
//     return ListTile(
//       contentPadding: EdgeInsets.zero,
//       leading: Container(
//         width: 40,
//         height: 40,
//         decoration: BoxDecoration(
//           color: Colors.blue[800],
//           shape: BoxShape.circle,
//         ),
//         child: Icon(Icons.directions_bus, color: Colors.white, size: 20),
//       ),
//       title: Text(
//         route,
//         style: const TextStyle(fontWeight: FontWeight.w600),
//       ),
//       subtitle: Text('$time • $distance'),
//       trailing: const Icon(Icons.arrow_forward_ios, size: 16),
//     );
//   }
//
//   Widget _buildRecentRoutesSection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'Recent Routes',
//           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//         ),
//         const SizedBox(height: 12),
//         _buildRecentRouteItem('Beliville Campus → District 6 Campus', 'Today, 9:30 AM'),
//         _buildRecentRouteItem('District 6 Campus → Mowbray Campus', 'Yesterday, 2:15 PM'),
//       ],
//     );
//   }
//
//   Widget _buildRecentRouteItem(String route, String time) {
//     return ListTile(
//       contentPadding: EdgeInsets.zero,
//       leading: Container(
//         width: 40,
//         height: 40,
//         decoration: BoxDecoration(
//           color: Colors.grey[300],
//           shape: BoxShape.circle,
//         ),
//         child: Icon(Icons.route, color: Colors.grey[700], size: 20),
//       ),
//       title: Text(
//         route,
//         style: const TextStyle(fontWeight: FontWeight.w500),
//       ),
//       subtitle: Text(time),
//     );
//   }
//
//   Widget _buildRegularShuttleScreen() {
//     return ListView(
//       padding: const EdgeInsets.all(16),
//       children: [
//         const Text(
//           '🚌 Shuttle Schedule',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//           textAlign: TextAlign.center,
//         ),
//         const SizedBox(height: 20),
//         _buildShuttleCard('Campus Express', '08:00 AM', 'Express Service', true),
//         _buildShuttleCard('Main Line', '09:30 AM', 'All Stops', true),
//         _buildShuttleCard('Residence Shuttle', '11:00 AM', 'Residence Areas', true),
//         _buildShuttleCard('Evening Service', '05:00 PM', 'Late Service', true),
//       ],
//     );
//   }
//
//   Widget _buildRegularAlertsScreen() {
//     return ListView(
//       padding: const EdgeInsets.all(16),
//       children: [
//         const Text(
//           '📢 Alerts & Notifications',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//           textAlign: TextAlign.center,
//         ),
//         const SizedBox(height: 20),
//         _buildAlertCard('Schedule Change', 'Shuttle times updated for finals week', Icons.info, Colors.blue),
//         _buildAlertCard('Weather Alert', 'Heavy rain expected today', Icons.cloud, Colors.blue),
//         _buildAlertCard('Maintenance', 'Shuttle #5 undergoing maintenance', Icons.build, Colors.orange),
//       ],
//     );
//   }
//
//   Widget _buildRegularProfileScreen() {
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: ListView(
//         children: [
//           // Profile Header with Avatar
//           const SizedBox(height: 20),
//           CircleAvatar(
//             radius: 50,
//             backgroundColor: Colors.blue[800],
//             child: Text(
//               widget.user != null
//                   ? '${widget.user!.name[0]}${widget.user!.surname[0]}'
//                   : 'JD',
//               style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
//             ),
//           ),
//           const SizedBox(height: 16),
//           Text(
//             widget.user != null
//                 ? '${widget.user!.name} ${widget.user!.surname}'
//                 : 'Student User',
//             style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             textAlign: TextAlign.center,
//           ),
//           Text(
//             widget.user != null ? widget.user!.userType : 'Student',
//             style: TextStyle(fontSize: 16, color: Colors.grey[600]),
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 30),
//
//           // Personal Information Section
//           const Text(
//             'Personal Information',
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 16),
//           _buildInfoCard('Email', widget.user?.email ?? 'Not available'),
//           const SizedBox(height: 12),
//           _buildInfoCard('Password', '••••••••', isPassword: true),
//           const SizedBox(height: 20),
//
//           // Change Password Button
//           ElevatedButton.icon(
//             icon: const Icon(Icons.lock_reset),
//             label: const Text('Change Password'),
//             onPressed: _changePassword,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.blue[800],
//               foregroundColor: Colors.white,
//               padding: const EdgeInsets.symmetric(vertical: 16),
//             ),
//           ),
//           const SizedBox(height: 30),
//
//           // App Settings Section
//           const Text(
//             'App Settings',
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 16),
//           _buildSettingSwitch('Notifications', 'Receive shuttle updates', true, (value) {}),
//           _buildSettingSwitch('Dark Mode', 'Use dark theme', false, (value) {}),
//           _buildSettingSwitch('Location Services', 'Allow location access', true, (value) {}),
//           const SizedBox(height: 30),
//
//           // Logout Button
//           OutlinedButton.icon(
//             icon: const Icon(Icons.logout),
//             label: const Text('Log Out'),
//             onPressed: _logout,
//             style: OutlinedButton.styleFrom(
//               foregroundColor: Colors.red,
//               side: const BorderSide(color: Colors.red),
//               padding: const EdgeInsets.symmetric(vertical: 16),
//             ),
//           ),
//           const SizedBox(height: 20),
//         ],
//       ),
//     );
//   }
//
// // Helper method to build information cards
//   Widget _buildInfoCard(String title, String value, {bool isPassword = false}) {
//     return Card(
//       elevation: 2,
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               title,
//               style: TextStyle(
//                 fontSize: 14,
//                 color: Colors.grey[600],
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//             const SizedBox(height: 4),
//             Text(
//               value,
//               style: const TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
// // Helper method to build setting switches
//   Widget _buildSettingSwitch(String title, String subtitle, bool value, Function(bool) onChanged) {
//     return SwitchListTile(
//       title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
//       subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
//       value: value,
//       onChanged: onChanged,
//       activeColor: Colors.blue[800],
//     );
//   }
//
// // Change Password Method
//   void _changePassword() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Change Password'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               obscureText: true,
//               decoration: const InputDecoration(
//                 labelText: 'Current Password',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 12),
//             TextField(
//               obscureText: true,
//               decoration: const InputDecoration(
//                 labelText: 'New Password',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//             const SizedBox(height: 12),
//             TextField(
//               obscureText: true,
//               decoration: const InputDecoration(
//                 labelText: 'Confirm New Password',
//                 border: OutlineInputBorder(),
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               // Add password change logic here
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text('Password changed successfully')),
//               );
//               Navigator.pop(context);
//             },
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800]),
//             child: const Text('Save', style: TextStyle(color: Colors.white)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // COMMON WIDGETS (keep your existing _buildWelcomeCard, _buildQuickAssistanceCard, etc.)
//   Widget _buildDisabledWelcomeCard() {
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Welcome, ${widget.user!.name}! 👋',
//               style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 10),
//             Text(
//               'Disability Type: ${_formatDisabilityType(widget.disabledStudent!.disabilityType)}',
//               style: TextStyle(fontSize: 16, color: Colors.grey[700]),
//             ),
//             const SizedBox(height: 8),
//             if (widget.disabledStudent!.accessNeeds.isNotEmpty)
//               Text(
//                 'Special Requirements: ${widget.disabledStudent!.accessNeeds}',
//                 style: TextStyle(fontSize: 16, color: Colors.grey[700]),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildQuickAssistanceCard() {
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               '🚨 Quick Assistance',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 15),
//             _buildAssistanceButton(
//               'Request Ramp Assistance',
//               Icons.ramp_right,
//               _rampAssistanceRequested,
//               _requestRampAssistance,
//             ),
//             const SizedBox(height: 10),
//             _buildAssistanceButton(
//               'Priority Boarding',
//               Icons.accessible_forward,
//               _priorityBoardingRequested,
//               _requestPriorityBoarding,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildAccessibilityFeaturesCard() {
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               '♿ Accessibility Features',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 15),
//             _buildFeatureStatus('Wheelchair Accessible Shuttles', true),
//             _buildFeatureStatus('Priority Seating', true),
//             _buildFeatureStatus('Audio Announcements', true),
//             _buildFeatureStatus('Visual Indicators', true),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildEmergencyContactsCard() {
//     return Card(
//       elevation: 4,
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               '📞 Emergency Contacts',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 15),
//             _buildContactTile('Campus Security', '021 123 4567', Icons.security),
//             _buildContactTile('Disability Unit', '021 123 4568', Icons.accessible),
//             _buildContactTile('Transport Office', '021 123 4569', Icons.directions_bus),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildShuttleCard(String route, String time, String features, bool isActive) {
//     return Card(
//       margin: const EdgeInsets.only(bottom: 15),
//       child: ListTile(
//         leading: Icon(
//           Icons.directions_bus,
//           color: isActive ? Colors.green : Colors.grey,
//           size: 32,
//         ),
//         title: Text(
//           route,
//           style: const TextStyle(fontWeight: FontWeight.bold),
//         ),
//         subtitle: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Time: $time'),
//             Text('Features: $features'),
//           ],
//         ),
//         trailing: Icon(
//           isActive ? Icons.check_circle : Icons.error,
//           color: isActive ? Colors.green : Colors.orange,
//         ),
//       ),
//     );
//   }
//
//   Widget _buildAlertCard(String title, String message, IconData icon, Color color) {
//     return Card(
//       margin: const EdgeInsets.only(bottom: 15),
//       child: ListTile(
//         leading: Icon(icon, color: color),
//         title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
//         subtitle: Text(message),
//         trailing: const Icon(Icons.arrow_forward),
//       ),
//     );
//   }
//
//   Widget _buildAssistanceButton(String text, IconData icon, bool isActive, VoidCallback onPressed) {
//     return ElevatedButton.icon(
//       icon: Icon(icon),
//       label: Text(text),
//       onPressed: onPressed,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: isActive ? Colors.green : Colors.blue[800],
//         foregroundColor: Colors.white,
//         minimumSize: const Size(double.infinity, 50),
//       ),
//     );
//   }
//
//   Widget _buildFeatureStatus(String feature, bool available) {
//     return ListTile(
//       leading: Icon(
//         available ? Icons.check_circle : Icons.error,
//         color: available ? Colors.green : Colors.red,
//       ),
//       title: Text(feature),
//       trailing: Text(
//         available ? 'Available' : 'Unavailable',
//         style: TextStyle(
//           color: available ? Colors.green : Colors.red,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//     );
//   }
//
//   Widget _buildContactTile(String name, String number, IconData icon) {
//     return ListTile(
//       leading: Icon(icon, color: Colors.green[800]),
//       title: Text(name),
//       subtitle: Text(number),
//       trailing: IconButton(
//         icon: const Icon(Icons.call, color: Colors.green),
//         onPressed: () => _makeCall(number),
//       ),
//     );
//   }
//
//
//
//   // Helper methods (keep your existing _formatDisabilityType, _requestRampAssistance, etc.)
//   String _formatDisabilityType(String type) {
//     switch (type) {
//       case 'physical': return 'Physical Disability';
//       case 'visual': return 'Visual Impairment';
//       case 'hearing': return 'Hearing Impairment';
//       case 'other': return 'Other Disability';
//       default: return type;
//     }
//   }
//
//   void _requestRampAssistance() {
//     setState(() => _rampAssistanceRequested = !_rampAssistanceRequested);
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(_rampAssistanceRequested
//             ? 'Ramp assistance requested'
//             : 'Ramp assistance cancelled'),
//       ),
//     );
//   }
//
//   void _requestPriorityBoarding() {
//     setState(() => _priorityBoardingRequested = !_priorityBoardingRequested);
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(_priorityBoardingRequested
//             ? 'Priority boarding requested'
//             : 'Priority boarding cancelled'),
//       ),
//     );
//   }
//
//   void _showEmergencyOptions() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Emergency Assistance'),
//         content: const Text('What type of emergency assistance do you need?'),
//         actions: [
//           TextButton(
//             onPressed: () => _makeCall('112'),
//             child: const Text('Medical Emergency'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _makeCall(String number) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Calling $number...')),
//     );
//   }
//
//   Future<void> _logout() async {
//     Navigator.pushReplacementNamed(context, '/login');
//   }
// }
=======

class StudentDashboard extends StatefulWidget {
  final User user;

  const StudentDashboard({Key? key, required this.user}) : super(key: key);

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 1:
        Navigator.pushReplacementNamed(
          context,
          '/student/shuttle_schedule',
          arguments: widget.user,
        );
        break;
      case 3:
        Navigator.pushNamed(
          context,
          '/student/profile',
          arguments: widget.user,
        );
        break;
    // Add other cases as needed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[900],
        title: Row(
          children: [
            Image.asset(
              'assets/images/cput_logo.png',
              height: 40,
            ),
            const SizedBox(width: 10),
            const Text(
              'Student Dashboard',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: const Center(
        child: Text('Welcome to Student Dashboard!'),
      ),

      /// 🔻 Footer / Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF009DD1), // #009dd1
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.alt_route),
            label: 'Shuttle Schedule', // Changed here
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

