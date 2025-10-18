import 'dart:convert';
import 'dart:io';
import 'package:firebase_admin/firebase_admin.dart' as admin;

class FirebaseAdminService {
  static final FirebaseAdminService _instance = FirebaseAdminService._internal();
  factory FirebaseAdminService() => _instance;
  FirebaseAdminService._internal();

  late final admin.App _app;
  late final dynamic _database; // use dynamic because Database type isn't exported by the package
  admin.Credential? _credential;
  bool _initialized = false;

  Future<void> init() async {
    final skip = (Platform.environment['SKIP_FIREBASE'] ?? '').toLowerCase();
    final shouldSkip = skip == '1' || skip == 'true' || skip == 'yes';

    // Obtain application default credentials (may be null if not configured)
    _credential = admin.Credentials.applicationDefault();
    if (_credential == null) {
      if (shouldSkip) {
        print('[FirebaseAdminService] SKIP_FIREBASE is set — skipping firebase initialization for local testing.');
        _initialized = false;
        return;
      }
      throw Exception(
          'No application default credentials found. Please set GOOGLE_APPLICATION_CREDENTIALS or provide credentials.');
    }

    // Initialize the Firebase app with the credential.
    _app = admin.FirebaseAdmin.instance.initializeApp(
      admin.AppOptions(
        credential: _credential!,
      ),
    );

    // Use Realtime Database (the firebase_admin package provides Database, not Firestore)
    _database = _app.database();
    _initialized = true;
  }

  /// Returns a small status map useful for health checks.
  Map<String, Object?> get status {
    return {
      'initialized': _initialized,
      'projectId': _initialized ? _app.options.projectId : null,
    };
  }

  Future<void> sendNotification(String token, String title, String body) async {
    final credential = _credential ?? admin.Credentials.applicationDefault();
    if (credential == null) {
      throw Exception('No application default credentials found. Cannot send notification.');
    }

    // Acquire an OAuth2 access token using the credential
    final accessToken = await credential.getAccessToken();

    final projectId = _app.options.projectId;
    if (projectId == null || projectId.isEmpty) {
      throw Exception('Firebase projectId is not set in app options.');
    }

    final uri = Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');
    final payload = jsonEncode({
      'message': {
        'token': token,
        'notification': {
          'title': title,
          'body': body,
        }
      }
    });

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${accessToken.accessToken}');
      request.write(payload);
      final response = await request.close();
      final respBody = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('FCM send failed (${response.statusCode}): $respBody');
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> updateShuttleLocation(
      String shuttleId, double latitude, double longitude) async {
    // Use Realtime Database to store shuttle location
    final ref = _database.ref('shuttle_locations/$shuttleId');
    await ref.set({
      'latitude': latitude,
      'longitude': longitude,
      // store ISO timestamp; Realtime Database server-side timestamp isn't exposed here
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  }
}