import 'package:flutter/material.dart';
import '../../models/user.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late User _user;

  int _selectedIndex = 3; // Profile tab selected

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args is User) {
      _user = args;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/student/dashboard', arguments: _user);
        break;
    // Add other cases for Shuttle Schedule, Alerts if you have those pages
      case 3:
      // Already on profile, do nothing
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
              'Profile',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Image
            Center(
              child: Image.asset(
                'assets/images/profile.png',
                height: 100,
                width: 100,
              ),
            ),

            const SizedBox(height: 20),

            // Full Name
            Text(
              '${_user.name} ${_user.surname}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            // Email
            Text(
              'Email: ${_user.email}',
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),

      /// Footer / Bottom Navigation Bar (consistent with StudentDashboard)
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
            label: 'Shuttle Schedule',  // Changed here
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
