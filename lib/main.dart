import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shuttle_tracker/screens/admin/manage_complaints.dart';
import 'package:shuttle_tracker/screens/admin/manage_route.dart';
import 'package:shuttle_tracker/screens/admin/admin_dashboard.dart';
import 'package:shuttle_tracker/screens/admin/manage_schedule.dart';
import 'screens/authentication/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/admin/assign_driver.dart';
import 'screens/admin/manage_notifications.dart';
import 'screens/admin/manage_shuttles.dart';
import 'screens/admin/manage_user.dart';
import 'screens/admin/profile.dart';
import 'screens/admin/manage_fleet.dart';
import 'screens/student/normal_students/normal_student_dashboard.dart';
import 'screens/student/disabled_student/disabled_student_dashboard.dart';
import 'screens/driver/driver_dashboard.dart';
import 'screens/ws_location_demo.dart';
import 'screens/auth/staff_login_screen.dart';
import 'screens/auth/admin_register_screen.dart';
import 'screens/admin_select_route.dart';
import 'providers/auth_provider.dart';
import 'providers/notifications_provider.dart';
import 'services/globals.dart' as globals;
// Global error logging
import 'dart:async';
import 'services/logger.dart';

void main() {
  // Print uncaught Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error('FlutterError.onError', error: details.exception, stackTrace: details.stack);
    FlutterError.presentError(details);
  };

  // Capture all other zone errors (async, timers, futures)
  runZonedGuarded(() {
    runApp(const MyApp());
  }, (Object error, StackTrace stackTrace) {
    AppLogger.exception('Uncaught zone error', error, stackTrace);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..tryAutoLogin()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
      ],
      child: Consumer<NotificationsProvider>(builder: (context, notif, _) {
        return MaterialApp(
          navigatorKey: globals.navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Shuttle Tracker',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.blue,
              accentColor: Colors.green,
            ),
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          // Use an auth gate so tests and app start at Login when not authenticated
          home: const _AuthGate(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/login/staff': (context) => const StaffLoginScreen(),
            '/register/admin': (context) => const AdminRegisterScreen(),
            '/student/dashboard': (context) => const NormalStudentDashboard(),
            '/student/disabled/dashboard': (context) => const DisabledStudentDashboard(),
            '/driver/dashboard': (context) => const DriverDashboard(),
            '/admin/dashboard': (context) => const AdminHomeScreen(),
            '/admin/users': (context) => const ManageUserScreen(),
            '/admin/shuttles': (context) => const ManageShuttlesScreen(),
            '/admin/fleet': (context) => const ManageFleetScreen(),
            '/admin/notifications': (context) => const ManageNotificationsScreen(),
            '/admin/profile': (context) => const AdminProfilePage(),
            '/admin/assign-driver': (context) => const AssignDriverScreen(),
            '/admin/complaints': (context) => const ManageComplaintsScreen(),
            '/admin/routes': (context) => const ManageRouteScreen(),
            '/admin/schedules': (context) => const ManageScheduleScreen(),
            '/admin/select_route': (context) => const AdminSelectRouteScreen(),
            // Development/demo route for WebSocket STOMP testing
            '/dev/ws-demo': (context) => const WsLocationDemoScreen(),
          },
        );
      }),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.isAuthenticated) {
      final role = (auth.role ?? '').toUpperCase();
      if (role == 'ADMIN') {
        return const AdminHomeScreen();
      } else if (role == 'DRIVER') {
        return const DriverDashboard();
      } else if (role == 'DISABLED_STUDENT') {
        return const DisabledStudentDashboard();
      } else {
        return const NormalStudentDashboard();
      }
    }

    return const LoginScreen();
  }
}
