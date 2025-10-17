// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shuttle_tracker/main.dart';

void main() {
  setUp(() async {
    // Ensure no persisted session in tests
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App boots to Login screen when not authenticated', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify that the login screen is displayed.
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
  });
}
