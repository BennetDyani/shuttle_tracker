import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'globals.dart' as globals;
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import 'logger.dart';

Future<void> performGlobalLogout() async {
  try {
    // Clear persisted auth keys
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('auth_user_id');
    await prefs.remove('auth_role');
  } catch (e) {
    AppLogger.warn('Failed to clear persisted auth in performGlobalLogout', data: e.toString());
  }

  // Clear globals
  globals.authToken = '';
  globals.refreshToken = '';
  globals.loggedInUserId = '';

  // Try to call providers via global navigator context
  try {
    final ctx = globals.navigatorKey.currentContext;
    if (ctx != null) {
      try {
        final auth = Provider.of<AuthProvider>(ctx, listen: false);
        auth.logout();
      } catch (e) {
        AppLogger.warn('No AuthProvider found during logout helper', data: e.toString());
      }
      try {
        final notif = Provider.of<NotificationsProvider>(ctx, listen: false);
        notif.clear();
      } catch (e) {
        AppLogger.warn('No NotificationsProvider found during logout helper', data: e.toString());
      }
      // Add other providers here as needed, catching errors if not present
    }
  } catch (e) {
    AppLogger.warn('Failed to call providers during performGlobalLogout', data: e.toString());
  }

  // Finally navigate to login screen (remove all routes)
  try {
    globals.navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
  } catch (e) {
    AppLogger.warn('Failed to navigate to login in performGlobalLogout', data: e.toString());
  }
}

