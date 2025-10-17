import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shuttle_tracker_backend/src/database.dart';

String hashPassword(String password) => sha256.convert(utf8.encode(password)).toString();

Future<void> main(List<String> args) async {
  final email = args.isNotEmpty ? args[0] : 'kabelomomo@hgtsadmin.cput.com';
  final expected = args.length > 1 ? args[1] : null;
  final db = Database();
  await db.connect();

  final res = await db.query('SELECT user_id, email, password_hash FROM users WHERE email = @email', substitutionValues: {'email': email});
  if (res.isEmpty) {
    print('No user found for $email');
    return;
  }
  final row = res.first.toColumnMap();
  final stored = row['password_hash'];
  print('user_id: \\${row['user_id']}, email: \\${row['email']}');
  print('stored_hash: $stored');
  if (expected != null) {
    final expectedHash = hashPassword(expected);
    print('expected_hash: $expectedHash');
    print('match: \\${expectedHash == stored}');
  }
}

