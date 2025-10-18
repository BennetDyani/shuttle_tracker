import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../models/User.dart' as AppUser;
import '../models/driver_model/Location.dart';
import '../models/driver_model/LocationMessage.dart';
import 'endpoints.dart';
import 'globals.dart' as globals;
import 'logger.dart';
import '../providers/auth_provider.dart';
import 'logout_helper.dart';

class APIService {
  // Singleton pattern
  static final APIService _instance = APIService._internal();
  factory APIService() => _instance;
  // allow injecting a custom client (useful for tests)
  http.Client httpClient = http.Client();
  APIService._internal();

  // Setter for tests to provide a MockClient
  void setHttpClient(http.Client client) {
    httpClient = client;
  }

  // Simple in-memory cache (key -> parsed JSON)
  final Map<String, dynamic> _cache = {};

  // Use configurable base URL from globals.dart (e.g., http://localhost:8080)
  String get _baseUrl => globals.apiBaseUrl;
  Uri _buildUri(String endpoint) {
    final base = _trimTrailingSlashes(_baseUrl);
    final path = _trimLeadingSlashes(endpoint);
    return Uri.parse('$base/$path');
  }

  Map<String, String> _defaultHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = globals.authToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Cache helpers
  void _setCache(String key, dynamic value, {bool persist = false}) async {
    _cache[key] = value;
    if (persist) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cache_' + key, jsonEncode(value));
      } catch (e) {
        AppLogger.warn('Failed to persist cache key $key', data: e.toString());
      }
    }
  }

  Future<dynamic> _getCache(String key) async {
    if (_cache.containsKey(key)) return _cache[key];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cache_' + key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        _cache[key] = decoded;
        return decoded;
      }
    } catch (e) {
      AppLogger.warn('Failed to read persisted cache key $key', data: e.toString());
    }
    return null;
  }

  void clearCache([String? key]) async {
    if (key == null) {
      _cache.clear();
      try {
        final prefs = await SharedPreferences.getInstance();
        for (final k in prefs.getKeys()) {
          if (k.startsWith('cache_')) await prefs.remove(k);
        }
      } catch (e) {
        AppLogger.warn('Failed to clear persisted cache', data: e.toString());
      }
    } else {
      _cache.remove(key);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cache_' + key);
      } catch (e) {
        AppLogger.warn('Failed to remove persisted cache key $key', data: e.toString());
      }
    }
  }

  Future<bool> _tryRefreshToken() async {
    try {
      final refreshPath = globals.authRefreshPath?.trim() ?? '';
      final refreshToken = globals.refreshToken;
      if (refreshPath.isEmpty || refreshToken == null || refreshToken.isEmpty) return false;
      final uri = _buildUri(refreshPath);
      AppLogger.info('Attempting token refresh via $uri');
      final body = jsonEncode({'refreshToken': refreshToken, 'refresh_token': refreshToken});
      final response = await httpClient.post(uri, headers: {'Content-Type': 'application/json'}, body: body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        // Extract tokens from common fields
        String? newToken;
        String? newRefresh;
        if (decoded['token'] is String) newToken = decoded['token'];
        if (newToken == null && decoded['accessToken'] is String) newToken = decoded['accessToken'];
        if (decoded['refreshToken'] is String) newRefresh = decoded['refreshToken'];
        if (newToken == null && decoded['data'] is Map<String, dynamic>) {
          final d = decoded['data'] as Map<String, dynamic>;
          if (d['token'] is String) newToken = d['token'];
          if (d['accessToken'] is String) newToken = d['accessToken'];
          if (d['refreshToken'] is String) newRefresh = d['refreshToken'];
        }
        if (newToken != null) {
          globals.authToken = newToken;
          if (newRefresh != null) globals.refreshToken = newRefresh;
          // Persist tokens
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('auth_token', globals.authToken);
            await prefs.setString('refresh_token', globals.refreshToken ?? '');
          } catch (e) {
            AppLogger.warn('Failed to persist refreshed tokens', data: e.toString());
          }
          AppLogger.info('Token refresh succeeded');
          return true;
        }
      } else {
        AppLogger.warn('Token refresh failed: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.warn('Token refresh exception', data: e.toString());
    }
    return false;
  }

  String _trimTrailingSlashes(String s) {
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  String _trimLeadingSlashes(String s) {
    while (s.startsWith('/')) {
      s = s.substring(1);
    }
    return s;
  }

  String _truncate(String? s, [int max = 800]) {
    if (s == null) return '';
    if (s.length <= max) return s;
    return s.substring(0, max) + '…';
  }

  // Generic GET request
  Future<dynamic> get(String endpoint) async {
    try {
      final uri = _buildUri(endpoint);
      AppLogger.debug('HTTP GET $uri');
      var response = await httpClient.get(uri, headers: _defaultHeaders());
      AppLogger.debug('HTTP GET ${response.statusCode}', data: _truncate(response.body));
      if (response.statusCode == 401) {
        // try refresh
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          response = await httpClient.get(uri, headers: _defaultHeaders());
          AppLogger.debug('HTTP GET retry ${response.statusCode}', data: _truncate(response.body));
        } else {
          // refresh failed -> force logout
          await _handleAuthFailure();
          throw Exception('Authentication failed and refresh unsuccessful');
        }
      }
      if (response.statusCode == 401) {
        // If still unauthorized after refresh
        await _handleAuthFailure();
        throw Exception('Authentication failed');
      }
      return _processResponse(response);
    } catch (e, st) {
      // If this is an ApiException (non-2xx response from server), log as a warning
      if (e is ApiException) {
        AppLogger.warn('API request returned non-2xx', data: {'endpoint': endpoint, 'status': e.statusCode, 'body': e.body});
        throw e;
      }
      AppLogger.exception('HTTP GET failed for $endpoint', e, st);
      return _handleError(e);
    }
  }

  // Generic POST request
  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = _buildUri(endpoint);
      final body = jsonEncode(data);
      AppLogger.debug('HTTP POST $uri', data: body);
      var response = await httpClient.post(uri, headers: _defaultHeaders(), body: body);
      AppLogger.debug('HTTP POST ${response.statusCode}', data: _truncate(response.body));
      if (response.statusCode == 401) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          response = await httpClient.post(uri, headers: _defaultHeaders(), body: body);
          AppLogger.debug('HTTP POST retry ${response.statusCode}', data: _truncate(response.body));
        } else {
          await _handleAuthFailure();
          throw Exception('Authentication failed and refresh unsuccessful');
        }
      }
      if (response.statusCode == 401) {
        await _handleAuthFailure();
        throw Exception('Authentication failed');
      }
      return _processResponse(response);
    } catch (e, st) {
      if (e is ApiException) {
        AppLogger.warn('API request returned non-2xx', data: {'endpoint': endpoint, 'status': e.statusCode, 'body': e.body});
        throw e;
      }
      AppLogger.exception('HTTP POST failed for $endpoint', e, st);
      return _handleError(e);
    }
  }

  // Generic PUT request
  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = _buildUri(endpoint);
      AppLogger.debug('HTTP PUT ${uri.toString()}', data: jsonEncode(data));
      var response = await httpClient.put(
        uri,
        headers: _defaultHeaders(),
        body: jsonEncode(data),
      );
      AppLogger.debug('HTTP PUT ${response.statusCode}', data: _truncate(response.body));
      if (response.statusCode == 401) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          response = await httpClient.put(
            uri,
            headers: _defaultHeaders(),
            body: jsonEncode(data),
          );
          AppLogger.debug('HTTP PUT retry ${response.statusCode}', data: _truncate(response.body));
        } else {
          await _handleAuthFailure();
          throw Exception('Authentication failed and refresh unsuccessful');
        }
      }
      if (response.statusCode == 401) {
        await _handleAuthFailure();
        throw Exception('Authentication failed');
      }
      return _processResponse(response);
    } catch (e, st) {
      if (e is ApiException) {
        AppLogger.warn('API request returned non-2xx', data: {'endpoint': endpoint, 'status': e.statusCode, 'body': e.body});
        throw e;
      }
      AppLogger.exception('HTTP PUT failed for $endpoint', e, st);
      return _handleError(e);
    }
  }

  // Generic DELETE request
  Future<dynamic> delete(String endpoint) async {
    try {
      final uri = _buildUri(endpoint);
      AppLogger.debug('HTTP DELETE ${uri.toString()}');
      var response = await httpClient.delete(uri, headers: _defaultHeaders());
      AppLogger.debug('HTTP DELETE ${response.statusCode}', data: _truncate(response.body));
      if (response.statusCode == 401) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          response = await httpClient.delete(uri, headers: _defaultHeaders());
          AppLogger.debug('HTTP DELETE retry ${response.statusCode}', data: _truncate(response.body));
        }
      }
      return _processResponse(response);
    } catch (e, st) {
      if (e is ApiException) {
        AppLogger.warn('API request returned non-2xx', data: {'endpoint': endpoint, 'status': e.statusCode, 'body': e.body});
        throw e;
      }
      AppLogger.exception('HTTP DELETE failed for $endpoint', e, st);
      return _handleError(e);
    }
  }

  // Convenience: fetch schedules with caching, pagination and filtering
  Future<List<dynamic>> fetchSchedules({int? userId, bool forceRefresh = false, int page = 1, int pageSize = 20, String? filter}) async {
    final params = <String, String>{};
    if (userId != null) params['userId'] = userId.toString();
    params['page'] = page.toString();
    params['pageSize'] = pageSize.toString();
    if (filter != null && filter.isNotEmpty) params['q'] = filter;
    final query = params.isNotEmpty ? '?${Uri(queryParameters: params).query}' : '';
    final endpoint = 'schedules/getAll$query';

    final cacheKey = endpoint; // simple key
    if (!forceRefresh) {
      final cached = await _getCache(cacheKey);
      if (cached is List<dynamic>) return cached;
    }

    final result = await get(endpoint);
    List<dynamic>? rawList;
    if (result is List) rawList = result;
    else if (result is Map<String, dynamic>) {
      if (result['data'] is List) rawList = result['data'] as List<dynamic>;
      else if (result['schedules'] is List) rawList = result['schedules'] as List<dynamic>;
    }
    if (rawList == null) throw Exception('Failed to fetch schedules: $result');
    _setCache(cacheKey, rawList, persist: true);
    return rawList;
  }

  // Convenience: fetch route stops with caching
  Future<List<dynamic>> fetchRouteStops(int routeId, {bool forceRefresh = false}) async {
    final endpoint = Endpoints.routeStopsReadByRouteId(routeId);
    final cacheKey = endpoint;
    if (!forceRefresh) {
      final cached = await _getCache(cacheKey);
      if (cached is List<dynamic>) return cached;
    }
    final result = await get(endpoint);
    if (result is List) {
      _setCache(cacheKey, result, persist: true);
      return result;
    }
    if (result is Map<String, dynamic>) {
      if (result['data'] is List) {
        _setCache(cacheKey, result['data'], persist: true);
        return result['data'] as List<dynamic>;
      }
      if (result['stops'] is List) {
        _setCache(cacheKey, result['stops'], persist: true);
        return result['stops'] as List<dynamic>;
      }
    }
    throw Exception('Failed to fetch route stops: $result');
  }

  // Example: Fetch all users
  Future<List<AppUser.User>> fetchUsers() async {
    final result = await get(Endpoints.userGetAll);
    // Backend may return a raw list or an object wrapper; normalize to list
    List<dynamic>? rawList;
    if (result is List) {
      rawList = result;
    } else if (result is Map<String, dynamic>) {
      if (result['data'] is List) rawList = result['data'] as List<dynamic>;
      else if (result['users'] is List) rawList = result['users'] as List<dynamic>;
    }

    if (rawList == null) throw Exception('Failed to fetch users: $result');

    final users = <AppUser.User>[];
    for (final item in rawList) {
      try {
        if (item is Map<String, dynamic>) {
          users.add(AppUser.User.fromJson(item));
        } else if (item is Map) {
          users.add(AppUser.User.fromJson(Map<String, dynamic>.from(item)));
        } else {
          AppLogger.warn('Skipping non-map user item', data: item);
        }
      } catch (e) {
        AppLogger.warn('Skipping invalid user JSON', data: {'error': e.toString(), 'item': item});
      }
    }
    return users;
  }

  // Auth: login with email and password
  Future<dynamic> login({required String email, required String password}) async {
    final payload = {'email': email, 'password': password};
    final endpoint = globals.overrideAuthLoginPath.trim().isNotEmpty ? globals.overrideAuthLoginPath.trim() : Endpoints.authLogin;
    return await post(endpoint, payload);
  }

  // New: Staff login with staffId and password
  Future<dynamic> staffLogin({required String staffId, required String password}) async {
    final payload = {'staffId': staffId, 'password': password};
    final endpoint = globals.overrideAuthStaffLoginPath.trim().isNotEmpty ? globals.overrideAuthStaffLoginPath.trim() : Endpoints.authStaffLogin;
    return await post(endpoint, payload);
  }

  // Registration: register a new user; payload should match backend contract
  Future<dynamic> registerUser(Map<String, dynamic> payload) async {
    return await post(Endpoints.userCreate, payload);
  }

  // Example: Create a new user (legacy; keep for compatibility)
  Future<AppUser.User> createUser(AppUser.User user) async {
    final result = await post(Endpoints.userCreate, user.toJson());
    if (result is Map<String, dynamic>) {
      return AppUser.User.fromJson(result);
    }
    throw Exception('Failed to create user: $result');
  }

  // Example: Update a user
  Future<AppUser.User> updateUser(int userId, AppUser.User user) async {
    final result = await put('users/$userId', user.toJson());
    if (result is Map<String, dynamic>) {
      return AppUser.User.fromJson(result);
    }
    throw Exception('Failed to update user: $result');
  }

  // Example: Delete a user
  Future<bool> deleteUser(int userId) async {
    final result = await delete('users/delete/$userId');
    return result == true || result == null;
  }

  // Shuttle-specific convenience methods (mirrors user helpers)
  Future<List<dynamic>> fetchShuttles() async {
    final result = await get(Endpoints.shuttleGetAll);
    if (result is List) return result;
    if (result is Map<String, dynamic>) {
      // Backend may wrap list inside { data: [...] }
      if (result['data'] is List) return result['data'] as List<dynamic>;
      if (result['shuttles'] is List) return result['shuttles'] as List<dynamic>;
    }
    throw Exception('Failed to fetch shuttles: $result');
  }

  // Fetch routes list for UI
  Future<List<dynamic>> fetchRoutes() async {
    final result = await get('routes/getAll');
    if (result is List) return result;
    if (result is Map<String, dynamic>) {
      if (result['data'] is List) return result['data'] as List<dynamic>;
      if (result['routes'] is List) return result['routes'] as List<dynamic>;
    }
    throw Exception('Failed to fetch routes: $result');
  }

  // Fetch drivers list for UI (used to populate assigned driver dropdown)
  Future<List<dynamic>> fetchDrivers() async {
    final result = await get(Endpoints.driverGetAll);
    if (result is List) return result;
    if (result is Map<String, dynamic>) {
      if (result['data'] is List) return result['data'] as List<dynamic>;
      if (result['drivers'] is List) return result['drivers'] as List<dynamic>;
    }
    throw Exception('Failed to fetch drivers: $result');
  }

  // Fetch notifications; supports optional filters
  Future<List<Map<String, dynamic>>> fetchNotifications({int? userId, bool? unread}) async {
    final params = <String, String>{};
    if (userId != null) params['userId'] = userId.toString();
    if (unread != null) params['unread'] = unread ? '1' : '0';
    final query = params.isNotEmpty ? '?${Uri(queryParameters: params).query}' : '';
    final result = await get('${Endpoints.notificationGetAll}$query');
    List<dynamic>? rawList;
    if (result is List) {
      rawList = result;
    } else if (result is Map<String, dynamic>) {
      if (result['data'] is List) rawList = result['data'] as List<dynamic>;
      else if (result['notifications'] is List) rawList = result['notifications'] as List<dynamic>;
      else if (result['notification'] is List) rawList = result['notification'] as List<dynamic>;
    }

    if (rawList == null) throw Exception('Failed to fetch notifications: $result');

    return rawList.map((e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e)).toList();
  }

  Future<dynamic> createShuttle(Map<String, dynamic> payload) async {
    return await post(Endpoints.shuttleCreate, payload);
  }

  Future<dynamic> updateShuttle(int shuttleId, Map<String, dynamic> payload) async {
    return await put('shuttles/$shuttleId', payload);
  }

  Future<bool> deleteShuttle(int shuttleId) async {
    final result = await delete('shuttles/delete/$shuttleId');
    return result == true || result == null;
  }

  // Create a complaint/feedback entry
  Future<dynamic> createComplaint({required int userId, required String title, required String description, int? statusId}) async {
    final payload = {
      'userId': userId,
      'title': title,
      'description': description,
      'statusId': statusId ?? 1,
    };
    return await post(Endpoints.complaintCreate, payload);
  }

  // --- Location-specific methods ---
  Future<List<Location>> fetchRecentLocations({int? limit, int? shuttleId, int? driverId}) async {
    final endpoint = Endpoints.locationRecent(limit: limit, shuttleId: shuttleId, driverId: driverId);
    final result = await get(endpoint);
    if (result is List) {
      return result.map((l) => Location.fromJson(l as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch locations: $result');
  }

  Future<List<LocationMessage>> fetchRecentLocationMessages({int? limit, int? shuttleId, int? driverId}) async {
    final endpoint = Endpoints.locationRecent(limit: limit, shuttleId: shuttleId, driverId: driverId);
    final result = await get(endpoint);
    if (result is List) {
      return result.map((l) => LocationMessage.fromJson(l as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch location messages: $result');
  }

  Future<bool> sendLocationMessage(LocationMessage msg) async {
    final result = await post(Endpoints.locationUpdate, msg.toJson());
    return result == null || result == true || result is String || result is Map<String, dynamic>;
  }

  Future<bool> updateLocation(Location location) async {
    final msg = LocationMessage(
      driverId: location.driver.driverId,
      shuttleId: location.shuttle.shuttleId,
      locationStatus: location.locationStatus,
      timestamp: location.recordedAt,
    );
    return await sendLocationMessage(msg);
  }

  // --- Error handling and response parsing ---
  dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      final decoded = jsonDecode(response.body);
      return decoded;
    } else {
      AppLogger.error('API Error ${response.statusCode}', data: _truncate(response.body));
      // Try to decode JSON body to provide structured errors to callers
      try {
        final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
        throw ApiException(response.statusCode, decoded, '${response.statusCode} ${response.reasonPhrase}');
      } catch (e) {
        // If decoding fails, include raw body string
        throw ApiException(response.statusCode, response.body, '${response.statusCode} ${response.reasonPhrase}');
      }
    }
  }

  dynamic _handleError(dynamic error) {
    AppLogger.error('Network/API Error', error: error);
    throw Exception('Network/API Error: $error');
  }

  Future<Map<String, dynamic>> fetchUserById(int userId) async {
    final result = await get(Endpoints.userReadById(userId));
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    throw Exception('Failed to fetch user: $result');
  }

  Future<Map<String, dynamic>> fetchDriverByEmail(String email) async {
    final endpoint = Endpoints.driverReadByEmail(email);
    final result = await get(endpoint);
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    throw Exception('Failed to fetch driver: $result');
  }

  // Mark a notification as read (best-effort). Clears notifications cache.
  Future<bool> markNotificationRead(int notificationId) async {
    try {
      // Backend accepts either `notificationId` or `id`, and expects `isRead`/`is_read`
      final payload = {
        'notificationId': notificationId,
        'id': notificationId,
        // Accept multiple common boolean keys for compatibility
        'isRead': true,
        'is_read': true,
        'read': true,
      };
      final res = await put(Endpoints.notificationUpdate, payload);
      // clear cached notifications so UI will refetch
      clearCache(Endpoints.notificationGetAll);
      return res != null;
    } catch (e) {
      AppLogger.warn('Failed to mark notification read', data: e.toString());
      return false;
    }
  }

  Future<void> _handleAuthFailure() async {
    AppLogger.info('Auth failure detected; performing global logout');
    try {
      await performGlobalLogout();
    } catch (e) {
      AppLogger.warn('performGlobalLogout failed', data: e.toString());
    }
  }
}

// Exception class that wraps non-2xx responses with decoded JSON body when available
// so callers can surface server-side validation errors.
// Example: throw ApiException(400, {'plate': 'Required', 'driver': 'Invalid'})
// Callers can catch ApiException and inspect `body`.
// Note: placed inside the file to keep scope local to the service.
// (It's fine to reference this class across the app.)
class ApiException implements Exception {
  final int statusCode;
  final dynamic body;
  final String message;

  ApiException(this.statusCode, this.body, [this.message = 'API Error']);

  @override
  String toString() => 'ApiException($statusCode): $message - $body';
}
