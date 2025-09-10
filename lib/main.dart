import 'package:flutter/material.dart';
import 'package:shuttle_tracker/screens/authentication/login_screen.dart';
import 'package:shuttle_tracker/screens/authentication/register_screen.dart';
//import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
//import 'package:authentication_app/auth_screen.dart';
import 'package:shuttle_tracker/screens/home_screen.dart';
import 'package:shuttle_tracker/screens/admin/admin_home_screen.dart';

import 'package:flutter/material.dart';
import 'package:shuttle_tracker/screens/authentication/login_screen.dart'; // Assuming LoginScreen is your initial screen or you have a wrapper.

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shuttle Tracker', // From your project name shuttle_tracker1
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // Primary color
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue, // Base for primary color shades
          accentColor: Colors
              .green, // Secondary color (also known as accent color)
          // You can also specify brightness, errorColor, etc. within ColorScheme if needed
          // For example:
          // brightness: Brightness.light,
          // errorColor: Colors.red,
        ),
        // It's also good practice to ensure visual density for cross-platform consistency.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AdminHomeScreen(), // Replace with your actual initial screen/widget if different
    );
  }
}





