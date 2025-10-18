import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:shuttle_tracker/providers/auth_provider.dart';
import 'package:shuttle_tracker/screens/student/normal_students/schedule_screen.dart';
import 'package:shuttle_tracker/services/APIService.dart';
import 'package:shuttle_tracker/services/globals.dart' as globals;

class TestAuthProvider extends AuthProvider {
  @override
  String? get userId => '1';

  @override
  bool get isInitialized => true;

  @override
  bool get isAuthenticated => true;
}

List<Map<String, dynamic>> makeSchedules(int start, int count) {
  return List.generate(count, (i) {
    final idx = start + i;
    return {
      'id': idx,
      'route': {'routeName': 'Route $idx', 'id': 100 + idx},
      'start': '08:00',
      'end': '09:00',
      'status': 'Upcoming',
      'shuttle': {'shuttleName': 'Shuttle $idx'},
    };
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Schedule pagination loads first page and then loads more', (WidgetTester tester) async {
    globals.apiBaseUrl = 'http://example.com/api';

    final mock = MockClient((http.Request request) async {
      // Check query params for page
      final q = request.url.queryParameters;
      final page = int.tryParse(q['page'] ?? '1') ?? 1;
      final pageSize = int.tryParse(q['pageSize'] ?? '12') ?? 12;

      if (request.method == 'GET' && request.url.path.contains('schedules/getAll')) {
        if (page == 1) {
          final data = makeSchedules(1, pageSize);
          return http.Response(jsonEncode(data), 200);
        } else if (page == 2) {
          final data = makeSchedules(1 + pageSize, 3);
          return http.Response(jsonEncode(data), 200);
        }
      }
      return http.Response('Not Found', 404);
    });

    APIService().setHttpClient(mock);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => TestAuthProvider()),
        ],
        child: const MaterialApp(home: StudentScheduleScreen()),
      ),
    );

    // Allow initial loads
    await tester.pumpAndSettle();

    // Should show pageSize items (12)
    expect(find.text('Route 1'), findsOneWidget);
    expect(find.text('Route 12'), findsOneWidget);

    // Tap the 'Load more' button
    expect(find.text('Load more'), findsOneWidget);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    // After loading more, expect one of the new entries from page 2 to appear
    expect(find.text('Route 13'), findsOneWidget);
  });
}

