import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/APIService.dart';
import '../services/logger.dart';
import '../services/globals.dart' as globals;

class AuthProvider extends ChangeNotifier {
  bool _initialized = false;
  bool _isAuthenticated = false;
  String? _userId;
  String? _role; // ADMIN, DRIVER, STUDENT, DISABLED_STUDENT, etc.

  bool get isInitialized => _initialized;
  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _userId;
  String? get role => _role;

  static const _kUserIdKey = 'auth_user_id';
  static const _kRoleKey = 'auth_role';

  Future<void> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString(_kUserIdKey);
      _role = prefs.getString(_kRoleKey);
      // Consider role presence sufficient for session restoration if userId missing
      final hasUserId = _userId != null && _userId!.isNotEmpty;
      final hasRole = _role != null && _role!.isNotEmpty;
      _isAuthenticated = hasUserId || hasRole;
      globals.loggedInUserId = _userId ?? '';
      AppLogger.info('AuthProvider auto-login', data: {
        'isAuthenticated': _isAuthenticated,
        'userId': _userId,
        'role': _role,
      });
    } catch (e, st) {
      AppLogger.exception('AuthProvider tryAutoLogin failed', e, st);
      _isAuthenticated = false;
      _userId = null;
      _role = null;
      globals.loggedInUserId = '';
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<String> loginWithEmail(String email, String password, {String? fallbackRole}) async {
    final result = await APIService().login(email: email, password: password);
    return ingestLoginResult(result, fallbackRole: fallbackRole);
  }

  Future<String> loginStaff({required String staffId, required String password, String? fallbackRole}) async {
    final result = await APIService().staffLogin(staffId: staffId, password: password);
    return ingestLoginResult(result, fallbackRole: fallbackRole);
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kUserIdKey);
      await prefs.remove(_kRoleKey);
    } catch (e, st) {
      AppLogger.exception('AuthProvider logout persistence failed', e, st);
    }
    _isAuthenticated = false;
    _userId = null;
    _role = null;
    globals.loggedInUserId = '';
    notifyListeners();
  }

  // Public: ingest an already-fetched login result and persist session
  String ingestLoginResult(dynamic result, {String? fallbackRole}) {
    return _handleAuthResult(result, fallbackRole: fallbackRole);
  }

  // --- helpers ---
  String _handleAuthResult(dynamic result, {String? fallbackRole}) {
    // Extract role and userId from various response shapes
    String? role;
    String? uid;

    if (result is Map<String, dynamic>) {
      // Common fields
      if (result['role'] is String) role = result['role'];
      if (result['userId'] is String) uid = result['userId'];
      if (uid == null && result['id'] is String) uid = result['id'];
      if (uid == null && result['id'] is int) uid = (result['id'] as int).toString();
      if (uid == null && result['userId'] is int) uid = (result['userId'] as int).toString();

      // Nested 'user'
      if (result['user'] is Map<String, dynamic>) {
        final user = result['user'] as Map<String, dynamic>;
        if (role == null && user['role'] is String) role = user['role'];
        if (uid == null && user['id'] is String) uid = user['id'];
        if (uid == null && user['id'] is int) uid = (user['id'] as int).toString();
        if (uid == null && user['userId'] is String) uid = user['userId'];
        if (uid == null && user['userId'] is int) uid = (user['userId'] as int).toString();
      }

      // Nested 'data'
      if (result['data'] is Map<String, dynamic>) {
        final data = result['data'] as Map<String, dynamic>;
        if (role == null && data['role'] is String) role = data['role'];
        if (uid == null && data['id'] is String) uid = data['id'];
        if (uid == null && data['id'] is int) uid = (data['id'] as int).toString();
        if (uid == null && data['userId'] is String) uid = data['userId'];
        if (uid == null && data['userId'] is int) uid = (data['userId'] as int).toString();
      }
    }

    // Use fallback if role still missing
    role ??= fallbackRole;

    if (role == null) {
      throw Exception('Login succeeded but role missing in response');
    }

    final normalizedRole = role.toString().toUpperCase();
    _role = normalizedRole;
    _userId = uid ?? '';
    _isAuthenticated = true;
    globals.loggedInUserId = _userId ?? '';

    _persist();
    notifyListeners();
    return normalizedRole;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userId != null) await prefs.setString(_kUserIdKey, _userId!);
      if (_role != null) await prefs.setString(_kRoleKey, _role!);
    } catch (e, st) {
      AppLogger.exception('AuthProvider persist failed', e, st);
    }
  }
}
