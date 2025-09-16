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
  int _currentIndex = 0;
  bool _rampAssistanceRequested = false;
  bool _priorityBoardingRequested = false;

  @override
  Widget build(BuildContext context) {
    // DEBUG: Print what we received
    print('🎯 StudentDashboard build called');
    print('🎯 User: ${widget.user?.name} (${widget.user?.userType})');
    print('🎯 DisabledStudent: ${widget.disabledStudent != null}');

    // If disabled student data is provided, show disabled dashboard content
    if (widget.disabledStudent != null && widget.user != null) {
      print('🎯 Showing DISABLED student dashboard');
      return _buildDisabledStudentDashboard();
    }

    // Otherwise show regular student dashboard
    print('🎯 Showing REGULAR student dashboard');
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.green[800],
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.accessible),
            label: 'Accessibility',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus),
            label: 'Shuttles',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.support_agent),
            label: 'Support',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return _buildAccessibilityScreen();
      case 1:
        return _buildShuttleScreen();
      case 2:
        return _buildSupportScreen();
      default:
        return _buildAccessibilityScreen();
    }
  }

  Widget _buildAccessibilityScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Welcome Card for Disabled Student
        _buildDisabledWelcomeCard(),
        const SizedBox(height: 20),

        // Quick Assistance
        _buildQuickAssistanceCard(),
        const SizedBox(height: 20),

        // Accessibility Features
        _buildAccessibilityFeaturesCard(),
        const SizedBox(height: 20),

        // Emergency Contacts
        _buildEmergencyContactsCard(),
      ],
    );
  }

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
            const SizedBox(height: 8),
            Text(
              'Minibus with Ramp: ${widget.disabledStudent!.exposureMinibus ? 'Required' : 'Not Required'}',
              style: TextStyle(
                fontSize: 16,
                color: widget.disabledStudent!.exposureMinibus ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAssistanceCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🚨 Quick Assistance',
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
              'Emergency Help',
              Icons.emergency,
              false,
              _showEmergencyOptions,
            ),
          ],
        ),
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

  Widget _buildAccessibilityFeaturesCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '♿ Accessibility Features',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            _buildFeatureStatus('Wheelchair Accessible Shuttles', true),
            _buildFeatureStatus('Priority Seating', true),
            _buildFeatureStatus('Audio Announcements', true),
            _buildFeatureStatus('Visual Indicators', true),
            _buildFeatureStatus('Low-floor Vehicles', true),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureStatus(String feature, bool available) {
    return ListTile(
      leading: Icon(
        available ? Icons.check_circle : Icons.error,
        color: available ? Colors.green : Colors.red,
      ),
      title: Text(feature),
      trailing: Text(
        available ? 'Available' : 'Unavailable',
        style: TextStyle(
          color: available ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
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
            _buildContactTile('Medical Emergency', '112', Icons.medical_services),
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

  Widget _buildShuttleScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '🚌 Accessible Shuttle Schedule',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _buildShuttleCard('Campus Express', '08:00 AM', 'Has Ramp', true),
        _buildShuttleCard('Main Line', '09:30 AM', 'Wheelchair Space', true),
        _buildShuttleCard('Residence Shuttle', '11:00 AM', 'No Ramp', false),
        _buildShuttleCard('Evening Service', '05:00 PM', 'Has Ramp', true),
      ],
    );
  }

  Widget _buildShuttleCard(String route, String time, String features, bool isAccessible) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      color: isAccessible ? Colors.green[50] : Colors.orange[50],
      child: ListTile(
        leading: Icon(
          isAccessible ? Icons.accessible : Icons.warning,
          color: isAccessible ? Colors.green : Colors.orange,
          size: 32,
        ),
        title: Text(
          route,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isAccessible ? Colors.green[800] : Colors.orange[800],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time: $time'),
            Text('Features: $features'),
          ],
        ),
        trailing: Icon(
          isAccessible ? Icons.check_circle : Icons.error,
          color: isAccessible ? Colors.green : Colors.orange,
        ),
      ),
    );
  }

  Widget _buildSupportScreen() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '🛟 Support Services',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _buildSupportOption('Schedule Regular Assistance', Icons.calendar_today, _scheduleAssistance),
        _buildSupportOption('Request Personal Attendant', Icons.person, _requestAttendant),
        _buildSupportOption('Accessibility Feedback', Icons.feedback, _giveFeedback),
        _buildSupportOption('Campus Accessibility Map', Icons.map, _showCampusMap),
        _buildSupportOption('Transportation FAQ', Icons.help, _showFAQ),
      ],
    );
  }

  Widget _buildSupportOption(String title, IconData icon, VoidCallback onPressed) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.green[800]),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward),
        onTap: onPressed,
      ),
    );
  }

  // Regular Student Dashboard
  Widget _buildRegularStudentDashboard() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.user != null
                ? 'Welcome, ${widget.user!.name}!'
                : 'Student Dashboard'
        ),
        backgroundColor: Colors.blue[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.user != null) ...[
              Text(
                'Welcome, ${widget.user!.name} ${widget.user!.surname}!',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Email: ${widget.user!.email}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 30),
            const Center(
              child: Text(
                'Regular Student Dashboard Content',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
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
        backgroundColor: _rampAssistanceRequested ? Colors.green : Colors.orange,
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
        backgroundColor: _priorityBoardingRequested ? Colors.green : Colors.orange,
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
            onPressed: () => _makeCall('0211234567'),
            child: const Text('Campus Security'),
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

  void _scheduleAssistance() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scheduling assistance...')),
    );
  }

  void _requestAttendant() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Requesting personal attendant...')),
    );
  }

  void _giveFeedback() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening feedback form...')),
    );
  }

  void _showCampusMap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening campus accessibility map...')),
    );
  }

  void _showFAQ() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening FAQ...')),
    );
  }



  Future<void> _logout() async {
    Navigator.pushReplacementNamed(context, '/login');
  }
}
