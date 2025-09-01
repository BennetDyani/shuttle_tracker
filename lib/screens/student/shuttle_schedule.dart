// lib/screens/student/shuttle_schedule.dart

import 'package:flutter/material.dart';
import '../../models/route.dart';
import '../../models/schedule.dart';
import '../../models/user.dart';

class ShuttleSchedulePage extends StatefulWidget {
  final User user;

  const ShuttleSchedulePage({Key? key, required this.user}) : super(key: key);

  @override
  State<ShuttleSchedulePage> createState() => _ShuttleScheduleState();
}

class _ShuttleScheduleState extends State<ShuttleSchedulePage> {
  bool isLoading = true;
  List<RouteModel> _routes = [];
  Map<int, List<Schedule>> _routeSchedules = {}; // routeId -> List<Schedule>
  int _selectedIndex = 1; // Shuttle Schedule tab selected

  @override
  void initState() {
    super.initState();
    _loadHardcodedRoutes();
  }

  void _loadHardcodedRoutes() {
    // ✅ Hardcoded routes
    final routes = [
      RouteModel(routeId: 1, origin: 'NMJ', destination: 'D6 Campus'),
      RouteModel(routeId: 2, origin: 'Catsville', destination: 'D6 Campus'),
      RouteModel(routeId: 3, origin: 'Rise', destination: 'D6 Campus'),
      RouteModel(routeId: 4, origin: 'Bellville Campus', destination: 'D6 Campus'),
      RouteModel(routeId: 5, origin: 'D6 Campus', destination: 'Mowbray Campus'),
      RouteModel(routeId: 6, origin: 'District 6 Campus', destination: 'Wellington Campus'),
    ];

    // ✅ Hardcoded schedules mapped by routeId
    final Map<int, List<Schedule>> schedules = {
      1: [
        Schedule(
          scheduleId: 101,
          shuttleId: 1,
          routeId: 1,
          departureTime: DateTime.parse('2025-09-01 06:30:00'),
          arrivalTime: DateTime.parse('2025-09-01 06:50:00'),
        ),
        Schedule(
          scheduleId: 102,
          shuttleId: 2,
          routeId: 1,
          departureTime: DateTime.parse('2025-09-01 07:00:00'),
          arrivalTime: DateTime.parse('2025-09-01 07:20:00'),
        ),
      ],
      2: [
        Schedule(
          scheduleId: 201,
          shuttleId: 3,
          routeId: 2,
          departureTime: DateTime.parse('2025-09-01 08:00:00'),
          arrivalTime: DateTime.parse('2025-09-01 08:30:00'),
        ),
      ],
      3: <Schedule>[], // No schedules for Rise yet
      4: [
        Schedule(
          scheduleId: 301,
          shuttleId: 4,
          routeId: 4,
          departureTime: DateTime.parse('2025-09-01 09:00:00'),
          arrivalTime: DateTime.parse('2025-09-01 09:45:00'),
        ),
        Schedule(
          scheduleId: 302,
          shuttleId: 5,
          routeId: 4,
          departureTime: DateTime.parse('2025-09-01 10:30:00'),
          arrivalTime: DateTime.parse('2025-09-01 11:15:00'),
        ),
      ],
      5: [
        Schedule(
          scheduleId: 401,
          shuttleId: 6,
          routeId: 5,
          departureTime: DateTime.parse('2025-09-01 12:00:00'),
          arrivalTime: DateTime.parse('2025-09-01 12:40:00'),
        ),
      ],
      6: [
        Schedule(
          scheduleId: 501,
          shuttleId: 7,
          routeId: 6,
          departureTime: DateTime.parse('2025-09-01 14:00:00'),
          arrivalTime: DateTime.parse('2025-09-01 15:20:00'),
        ),
      ],
    };

    setState(() {
      _routes = routes;
      _routeSchedules = schedules;
      isLoading = false;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/student/dashboard',
            arguments: widget.user);
        break;
      case 1:
      // Already on shuttle schedule, do nothing
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/student/alerts',
            arguments: widget.user);
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/student/profile',
            arguments: widget.user);
        break;
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
              'Shuttle Schedule',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _routes.isEmpty
          ? const Center(child: Text('No shuttle routes found'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _routes.length,
        itemBuilder: (context, index) {
          final route = _routes[index];
          final schedules = _routeSchedules[route.routeId] ?? [];

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ExpansionTile(
              title: Text(
                '${route.origin} → ${route.destination}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              initiallyExpanded: true, // open all by default
              children: schedules.isEmpty
                  ? const [
                ListTile(
                  title: Text('No schedules available'),
                )
              ]
                  : schedules.map((schedule) {
                return ListTile(
                  title: Text(
                    'Departure: ${TimeOfDay.fromDateTime(schedule.departureTime).format(context)}',
                  ),
                  subtitle: Text(
                    'Arrival: ${TimeOfDay.fromDateTime(schedule.arrivalTime).format(context)}',
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF009DD1),
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
            label: 'Shuttle Schedule',
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
