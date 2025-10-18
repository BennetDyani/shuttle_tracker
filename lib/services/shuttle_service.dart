import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/platform_utils_stub.dart' if (dart.library.io) '../utils/platform_utils_io.dart';
import '../models/shuttle_model.dart';

class ShuttleService {
  // Automatically use the emulator host for Android emulators
  final String baseUrl = (() {
    final host = (PlatformUtils.isAndroid && !kIsWeb) ? '10.0.2.2' : 'localhost';
    return 'http://$host:8080/api';
  })();

  // Helper to robustly extract a List<Map<String, dynamic>> from a response body
  List<Map<String, dynamic>> _extractListFromBody(String body, {List<String>? keysToTry}) {
    if (body.trim().isEmpty) return [];
    final dynamic decoded = json.decode(body);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    if (decoded is Map<String, dynamic>) {
      keysToTry ??= ['data', 'items', 'rows', 'drivers', 'schedules', 'users', 'assignments', 'result', 'payload'];
      for (final k in keysToTry) {
        if (decoded.containsKey(k)) {
          final v = decoded[k];
          if (v is List) return v.cast<Map<String, dynamic>>();
        }
      }
      // Some APIs wrap the array at the first key
      for (final v in decoded.values) {
        if (v is List) return v.cast<Map<String, dynamic>>();
      }
    }
    // Unknown shape -> return empty list but leave caller to handle
    return [];
  }

  Future<List<Shuttle>> getShuttles() async {
    final response = await http.get(Uri.parse('$baseUrl/shuttles/getAll'));
    debugPrint('[ShuttleService] GET $baseUrl/shuttles/getAll -> ${response.statusCode}');
    debugPrint('[ShuttleService] shuttles response body: ${response.body}');
    if (response.statusCode == 200) {
      try {
        final extracted = _extractListFromBody(response.body, keysToTry: ['shuttles', 'data', 'items']);
        if (extracted.isNotEmpty) {
          return extracted.map((json) => Shuttle.fromJson(json)).toList();
        }
        // Fallback: maybe the endpoint returns an array of objects directly
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Shuttle.fromJson(json)).toList();
      } catch (e) {
        throw Exception('Failed to parse shuttles response: $e -- body: ${response.body}');
      }
    } else {
      throw Exception('Failed to load shuttles: ${response.statusCode} ${response.body}');
    }
  }

  Future<Shuttle> createShuttle(Shuttle shuttle) async {
    final response = await http.post(
      Uri.parse('$baseUrl/shuttles/create'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(shuttle.toJson()),
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final shuttleJson = data['shuttle'] ?? data;
      return Shuttle.fromJson(shuttleJson as Map<String, dynamic>);
    } else {
      throw Exception('Failed to create shuttle: ${response.statusCode} ${response.body}');
    }
  }

  Future<Shuttle> updateShuttle(int id, Shuttle shuttle) async {
    final response = await http.put(
      Uri.parse('$baseUrl/shuttles/update/$id'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(shuttle.toJson()),
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final shuttleJson = data['shuttle'] ?? data;
      return Shuttle.fromJson(shuttleJson as Map<String, dynamic>);
    } else {
      throw Exception('Failed to update shuttle: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> deleteShuttle(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/shuttles/delete/$id'));
    if (response.statusCode == 200) {
      return;
    } else {
      throw Exception('Failed to delete shuttle: ${response.statusCode} ${response.body}');
    }
  }

  Future<Shuttle> updateShuttleStatus(int id, int statusId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/shuttles/$id/status'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({'statusId': statusId}),
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final shuttleJson = data['shuttle'] ?? data;
      return Shuttle.fromJson(shuttleJson as Map<String, dynamic>);
    } else {
      throw Exception('Failed to update shuttle status: ${response.statusCode} ${response.body}');
    }
  }

  // Fetches shuttle statuses from the backend
  Future<List<Map<String, dynamic>>> fetchStatuses() async {
    final response = await http.get(Uri.parse('$baseUrl/shuttles/statuses'));
    debugPrint('[ShuttleService] GET $baseUrl/shuttles/statuses -> ${response.statusCode}');
    debugPrint('[ShuttleService] statuses response body: ${response.body}');
    if (response.statusCode == 200) {
      return _extractListFromBody(response.body, keysToTry: ['statuses', 'data', 'items']);
    } else {
      throw Exception('Failed to fetch shuttle statuses: ${response.statusCode} ${response.body}');
    }
  }

  // Fetches shuttle types from the backend
  Future<List<Map<String, dynamic>>> fetchTypes() async {
    final response = await http.get(Uri.parse('$baseUrl/shuttles/types'));
    debugPrint('[ShuttleService] GET $baseUrl/shuttles/types -> ${response.statusCode}');
    debugPrint('[ShuttleService] types response body: ${response.body}');
    if (response.statusCode == 200) {
      return _extractListFromBody(response.body, keysToTry: ['types', 'data', 'items']);
    } else {
      throw Exception('Failed to fetch shuttle types: ${response.statusCode} ${response.body}');
    }
  }

  // Fetch drivers list
  Future<List<Map<String, dynamic>>> getDrivers() async {
    final response = await http.get(Uri.parse('$baseUrl/drivers/getAll'));
    debugPrint('[ShuttleService] GET $baseUrl/drivers/getAll -> ${response.statusCode}');
    debugPrint('[ShuttleService] drivers response body: ${response.body}');
    if (response.statusCode == 200) {
      return _extractListFromBody(response.body, keysToTry: ['drivers', 'data', 'items']);
    } else {
      throw Exception('Failed to fetch drivers: ${response.statusCode} ${response.body}');
    }
  }

  // Fetch users list (to resolve driver names)
  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final response = await http.get(Uri.parse('$baseUrl/users/getAll'));
    debugPrint('[ShuttleService] GET $baseUrl/users/getAll -> ${response.statusCode}');
    debugPrint('[ShuttleService] users response body: ${response.body}');
    if (response.statusCode == 200) {
      return _extractListFromBody(response.body, keysToTry: ['users', 'data', 'items']);
    } else {
      throw Exception('Failed to fetch users: ${response.statusCode} ${response.body}');
    }
  }

  // Fetch schedules list
  Future<List<Map<String, dynamic>>> getSchedules() async {
    final response = await http.get(Uri.parse('$baseUrl/schedules/getAll'));
    debugPrint('[ShuttleService] GET $baseUrl/schedules/getAll -> ${response.statusCode}');
    debugPrint('[ShuttleService] schedules response body: ${response.body}');
    if (response.statusCode == 200) {
      return _extractListFromBody(response.body, keysToTry: ['schedules', 'data', 'items']);
    } else {
      throw Exception('Failed to fetch schedules: ${response.statusCode} ${response.body}');
    }
  }

  // Create a driver assignment
  Future<Map<String, dynamic>> createDriverAssignment({required dynamic driverId, required dynamic shuttleId, required dynamic scheduleId, String? assignmentDate}) async {
    // Accept dynamic id types (int or String/UUID) and send them as-is in the request
    final body = {
      'driverId': driverId,
      'shuttleId': shuttleId,
      'scheduleId': scheduleId,
      'assignmentDate': assignmentDate ?? DateTime.now().toIso8601String(),
    };
    final response = await http.post(
      Uri.parse('$baseUrl/assignments/create'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return data['assignment'] ?? data;
    } else {
      throw Exception('Failed to create assignment: ${response.statusCode} ${response.body}');
    }
  }

  // Fetch existing driver assignments
  Future<List<Map<String, dynamic>>> getDriverAssignments() async {
    final response = await http.get(Uri.parse('$baseUrl/assignments/getAll'));
    debugPrint('[ShuttleService] GET $baseUrl/assignments/getAll -> ${response.statusCode}');
    debugPrint('[ShuttleService] assignments response body: ${response.body}');
    if (response.statusCode == 200) {
      return _extractListFromBody(response.body, keysToTry: ['assignments', 'data', 'items']);
    } else {
      throw Exception('Failed to fetch assignments: ${response.statusCode} ${response.body}');
    }
  }

  // Create a schedule
  Future<Map<String, dynamic>> createSchedule({required dynamic routeId, required String departureTime, required String arrivalTime, required String dayOfWeek}) async {
    final body = {
      'routeId': routeId,
      'departureTime': departureTime,
      'arrivalTime': arrivalTime,
      'dayOfWeek': dayOfWeek,
    };
    final response = await http.post(
      Uri.parse('$baseUrl/schedules/create'),
      headers: <String, String>{'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode(body),
    );
    debugPrint('[ShuttleService] POST $baseUrl/schedules/create -> ${response.statusCode}');
    debugPrint('[ShuttleService] create schedule body: ${response.body}');
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return data['schedule'] ?? data;
    } else {
      throw Exception('Failed to create schedule: ${response.statusCode} ${response.body}');
    }
  }

  // Fetch routes list
  Future<List<Map<String, dynamic>>> getRoutes() async {
    final response = await http.get(Uri.parse('$baseUrl/routes/getAll'));
    debugPrint('[ShuttleService] GET $baseUrl/routes/getAll -> ${response.statusCode}');
    debugPrint('[ShuttleService] routes response body: ${response.body}');
    if (response.statusCode == 200) {
      return _extractListFromBody(response.body, keysToTry: ['routes', 'data', 'items']);
    } else {
      throw Exception('Failed to fetch routes: ${response.statusCode} ${response.body}');
    }
  }

  // Create a route
  Future<Map<String, dynamic>> createRoute({required String name, String? description}) async {
    final body = {
      'name': name,
      if (description != null) 'description': description,
    };
    final response = await http.post(
      Uri.parse('$baseUrl/routes/create'),
      headers: <String, String>{'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode(body),
    );
    debugPrint('[ShuttleService] POST $baseUrl/routes/create -> ${response.statusCode}');
    debugPrint('[ShuttleService] create route body: ${response.body}');
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return data['route'] ?? data;
    } else {
      throw Exception('Failed to create route: ${response.statusCode} ${response.body}');
    }
  }

  // Debug helper: return raw response status and body for a given relative path
  Future<Map<String, dynamic>> debugGetRaw(String relativePath) async {
    final url = '$baseUrl/$relativePath';
    final response = await http.get(Uri.parse(url));
    debugPrint('[ShuttleService] DEBUG GET $url -> ${response.statusCode}');
    debugPrint('[ShuttleService] DEBUG body: ${response.body}');
    return {'status': response.statusCode, 'body': response.body, 'url': url};
  }
}
