import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:shuttle_tracker_backend/src/database.dart';

String _hash(String s) => sha256.convert(utf8.encode(s)).toString();

Future<Map<String, dynamic>> postJson(String url, Map<String, dynamic> body) async {
  final uri = Uri.parse(url);
  final client = HttpClient();
  try {
    final req = await client.postUrl(uri);
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    req.add(utf8.encode(jsonEncode(body)));
    final res = await req.close();
    final bodyStr = await utf8.decoder.bind(res).join();
    return {'status': res.statusCode, 'body': bodyStr};
  } finally {
    client.close();
  }
}

Future<void> main() async {
  final email = 'kabelomomo@hgtsadmin.cput.com';
  final newPass = 'secret123';
  final db = Database();
  await db.connect();
  print('DB connected: ${db.isConnected}');

  // Update password
  final hashed = _hash(newPass);
  await db.query('UPDATE users SET password_hash = @hash WHERE email = @email', substitutionValues: {'hash': hashed, 'email': email});
  print('Password updated for $email');

  // Fetch staff_id
  final staffRes = await db.query('SELECT s.staff_id FROM staff s JOIN users u ON s.user_id = u.user_id WHERE u.email = @email', substitutionValues: {'email': email});
  String? staffId;
  if (staffRes.isNotEmpty) staffId = staffRes.first.toColumnMap()['staff_id']?.toString();
  print('staff_id for $email: $staffId');

  // Try login by email
  final url = 'http://localhost:8080/api/auth/staff-login';
  print('\nPOST $url by email ->');
  final r1 = await postJson(url, {'email': email, 'password': newPass});
  print('status=${r1['status']} body=${r1['body']}');

  // Try login by staffId if available
  if (staffId != null) {
    print('\nPOST $url by staffId ->');
    final r2 = await postJson(url, {'staffId': staffId, 'password': newPass});
    print('status=${r2['status']} body=${r2['body']}');
  }

  // Close DB if needed
  exit(0);
}

