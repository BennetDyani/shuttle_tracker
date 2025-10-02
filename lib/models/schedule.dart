import 'package:flutter/material.dart';
import '../../models/route.dart';
import '../../models/schedule.dart';
import '../../utils/database_connection.dart';
import '../../models/user.dart';

class ShuttleSchedule extends StatefulWidget {
  final User user;

  const ShuttleSchedule({Key? key, required this.user}) : super(key: key);

  @override
  State<ShuttleSchedule> createState() => _ShuttleScheduleState();
}

class _ShuttleScheduleState extends State<ShuttleSchedule> {
  bool isLoading = true;
  List<RouteModel> _routes = [];
  Map<int, List<Schedule>> _routeSchedules = {}; // routeId -> List<Schedule>
  int _selectedIndex = 1; // Shuttle Schedule tab selected

  @override
  void initState() {
    super.initState();
    fetchRoutesAndSchedules();
  }

  Future<void> fetchRoutesAndSchedules() async {
    try {
      final conn = await DatabaseConnection.getConnection();

      var routeResults = await conn.query('SELECT * FROM route');
      List<RouteModel> routes = routeResults
          .map((r) => RouteModel.fromMap(r.fields))
          .toList();

      Map<int, List<Schedule>> schedulesMap = {};

      for (var route in routes) {
        var scheduleResults = await conn.query(
          'SELECT * FROM schedule WHERE route_id = ? ORDER BY departure_time',
          [route.routeId],
        );

        schedulesMap[route.routeId] = scheduleResults
            .map((s) => Schedule.fromMap(s.fields))
            .toList();
      }

      setState(() {
        _routes = routes;
        _routeSchedules = schedulesMap;
        isLoading = false;
      });

      // Do NOT close conn, it’s pooled

    } catch (e) {
      print('Error fetching shuttle schedules: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/student/dashboard', arguments: widget.user);
        break;
      case 1:
      // Already on shuttle schedule, do nothing
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/student/alerts', arguments: widget.user);
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/student/profile', arguments: widget.user);
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
              children: schedules.isEmpty
                  ? [
                const ListTile(
                  title: Text('No schedules available'),
                )
              ]
                  : schedules.map((schedule) {
                return ListTile(
                  title: Text(
                      'Departure: ${TimeOfDay.fromDateTime(schedule.departureTime).format(context)}'),
                  subtitle: Text(
                      'Arrival: ${TimeOfDay.fromDateTime(schedule.arrivalTime).format(context)}'),
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
