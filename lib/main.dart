import 'package:flutter/material.dart';
import 'package:shuttle_tracker/screens/authentication/login_screen.dart';
import 'package:shuttle_tracker/screens/authentication/register_screen.dart';
//import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
//import 'package:authentication_app/auth_screen.dart';
import 'package:shuttle_tracker/screens/home_screen.dart';
import 'package:shuttle_tracker/screens/admin/admin_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Authentication App',
      theme: ThemeData(

        primarySwatch: Colors.blue,
      ),
      home: const LoginScreen(), // HomeScreen as the home widget
    );
  }
}





