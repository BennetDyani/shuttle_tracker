import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/User.dart';
import '../models/driver_model/Location.dart';
import '../models/driver_model/LocationMessage.dart';
import 'endpoints.dart';
import 'globals.dart' as globals;
import 'logger.dart';

class APIService {
  // Singleton pattern
  static final APIService _instance = APIService._internal();
  factory APIService() => _instance;
  APIService._internal();

  // Use configurable base URL from globals.dart (e.g., http://localhost:8080)
  String get _baseUrl => globals.apiBaseUrl;
  Uri _buildUri(String endpoint) {
    final base = _trimTrailingSlashes(_baseUrl);
    final path = _trimLeadingSlashes(endpoint);
    return Uri.parse('$base/$path');
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
      final response = await http.get(uri);
      AppLogger.debug('HTTP GET ${response.statusCode}', data: _truncate(response.body));
      return _processResponse(response);
    } catch (e, st) {
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
      final response = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body);
      AppLogger.debug('HTTP POST ${response.statusCode}', data: _truncate(response.body));
      return _processResponse(response);
    } catch (e, st) {
      AppLogger.exception('HTTP POST failed for $endpoint', e, st);
      return _handleError(e);
    }
  }

  // Generic PUT request
  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = _buildUri(endpoint);
      AppLogger.debug('HTTP PUT ${uri.toString()}', data: jsonEncode(data));
      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      AppLogger.debug('HTTP PUT ${response.statusCode}', data: _truncate(response.body));
      return _processResponse(response);
    } catch (e, st) {
      AppLogger.exception('HTTP PUT failed for $endpoint', e, st);
      return _handleError(e);
    }
  }

  // Generic DELETE request
  Future<dynamic> delete(String endpoint) async {
    try {
      final uri = _buildUri(endpoint);
      AppLogger.debug('HTTP DELETE ${uri.toString()}');
      final response = await http.delete(uri);
      AppLogger.debug('HTTP DELETE ${response.statusCode}', data: _truncate(response.body));
      return _processResponse(response);
    } catch (e, st) {
      AppLogger.exception('HTTP DELETE failed for $endpoint', e, st);
      return _handleError(e);
    }
  }

  // Example: Fetch all users
  Future<List<User>> fetchUsers() async {
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

    final users = <User>[];
    for (final item in rawList) {
      try {
        if (item is Map<String, dynamic>) {
          users.add(User.fromJson(item));
        } else if (item is Map) {
          users.add(User.fromJson(Map<String, dynamic>.from(item)));
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
  Future<User> createUser(User user) async {
    final result = await post(Endpoints.userCreate, user.toJson());
    if (result is Map<String, dynamic>) {
      return User.fromJson(result);
    }
    throw Exception('Failed to create user: $result');
  }

  // Example: Update a user
  Future<User> updateUser(int userId, User user) async {
    final result = await put('users/$userId', user.toJson());
    if (result is Map<String, dynamic>) {
      return User.fromJson(result);
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
