import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/admin_login_screen.dart';
import 'screens/auth/admin_register_screen.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/admin/admin_dashboard.dart';

void main() {
  runApp(const ShuttleTrackingApp());
}

class ShuttleTrackingApp extends StatelessWidget {
  const ShuttleTrackingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CPUT Shuttle Tracking',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/admin/login': (context) => const AdminLoginScreen(),
        '/admin/register': (context) => const AdminRegisterScreen(),
        '/register': (context) => const RegisterScreen(),
        '/student/dashboard': (context) => const StudentDashboard(),
        '/admin/dashboard': (context) => const AdminDashboard(),
      },
    );
  }
}