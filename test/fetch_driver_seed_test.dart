import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

import 'package:shuttle_tracker/services/APIService.dart';
import 'package:shuttle_tracker/services/globals.dart' as globals;
import 'package:shuttle_tracker/services/shuttle_service.dart';

class TestShuttleService extends ShuttleService {
  bool called = false;
  dynamic lastUserId;

  @override
  Future<Map<String, dynamic>> createDriverFromUser(dynamic userId) async {
    called = true;
    lastUserId = userId;
    // return a synthetic driver record
    return {'driver_id': 555, 'user_id': userId, 'license_number': 'TEST'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fetchDriverByEmail seeds driver on 404 then returns driver', () async {
    globals.apiBaseUrl = 'http://localhost:8080/api';

    final email = 'knosi@hgtsdriver.cput.com';
    final encoded = Uri.encodeComponent(email);
    final driverPath = '/api/drivers/readByEmail/$encoded';
    final userPath = '/api/users/readByEmail/$encoded';

    // Track calls by path
    final Map<String, int> callCount = {};

    final mock = MockClient((http.Request request) async {
      final path = request.url.path;
      callCount[path] = (callCount[path] ?? 0) + 1;

      if (path == driverPath) {
        final cnt = callCount[path]!;
        if (cnt == 1) {
          // First attempt: driver not found
          return http.Response(jsonEncode({'error': 'Driver not found'}), 404, headers: {'content-type': 'application/json'});
        }
        // Second attempt: return the created driver
        return http.Response(jsonEncode({'driver_id': 555, 'user_id': 18, 'license_number': 'TEST'}), 200, headers: {'content-type': 'application/json'});
      }

      if (path == userPath) {
        // Return the user record so seeding can proceed
        return http.Response(jsonEncode({'user_id': 18, 'first_name': 'Nkosi', 'last_name': 'Nathi', 'email': email}), 200, headers: {'content-type': 'application/json'});
      }

      return http.Response('Not Found', 404);
    });

    final api = APIService();
    api.setHttpClient(mock);
    // inject test shuttle service so no real HTTP calls are made for seeding logic
    final testShuttle = TestShuttleService();
    api.setShuttleService(testShuttle);

    final result = await api.fetchDriverByEmail(email);
    expect(result, isA<Map<String, dynamic>>());
    expect(result['driver_id'], 555);
    expect(testShuttle.called, isTrue);
    expect(testShuttle.lastUserId, 18);
  });
}

