import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:shuttle_tracker/providers/auth_provider.dart';
import 'package:shuttle_tracker/services/APIService.dart';
import 'package:shuttle_tracker/services/globals.dart' as globals;

class TestAuthProvider extends AuthProvider {
  bool loggedOut = false;

  @override
  Future<void> logout() async {
    // Avoid persisting changes in tests; just mark flag
    loggedOut = true;
    // Do not call super.logout() to avoid SharedPreferences in unit test
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('APIService triggers AuthProvider.logout when refresh fails', (WidgetTester tester) async {
    // Arrange: set globals
    globals.apiBaseUrl = 'http://example.com/api';
    globals.authRefreshPath = 'auth/refresh';
    globals.refreshToken = 'dummy-refresh-token';
    globals.authToken = 'expired-token';

    // Prepare a MockClient that returns 401 for the original GET and a failing response for refresh POST
    final mock = MockClient((http.Request request) async {
      if (request.method == 'GET') {
        return http.Response('Unauthorized', 401);
      }
      if (request.method == 'POST' && request.url.path.contains('refresh')) {
        // Simulate refresh failure
        return http.Response(jsonEncode({'error': 'refresh failed'}), 400);
      }
      return http.Response('Not Found', 404);
    });

    APIService().setHttpClient(mock);

    final testAuth = TestAuthProvider();

    // Pump a small app with navigatorKey set so APIService can access context
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider<AuthProvider>.value(value: testAuth)],
        child: MaterialApp(
          navigatorKey: globals.navigatorKey,
          home: const SizedBox.shrink(),
        ),
      ),
    );

    // Allow the widget tree to build and attach the navigatorKey context
    await tester.pumpAndSettle();

    // Act: call an endpoint which will 401 and trigger refresh. Ignore exception but allow side-effects.
    try {
      await APIService().get('some/protected');
    } catch (_) {}

    // Give microtasks a chance and let auth failure handler run
    await tester.pumpAndSettle();

    // Assert logout side-effect
    expect(testAuth.loggedOut, isTrue);
    expect(globals.authToken, isEmpty);
    expect(globals.refreshToken, isEmpty);
  });
}
