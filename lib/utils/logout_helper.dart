import 'package:flutter/widgets.dart';
import '../services/logout_helper.dart' as service;

/// Utility class to provide a convenient logout API
class LogoutHelper {
  /// Log out the current user and navigate to login screen
  static Future<void> logout(BuildContext context) async {
    await service.performGlobalLogout();
  }

  /// Perform global logout without requiring a context
  static Future<void> performGlobalLogout() async {
    await service.performGlobalLogout();
  }
}
