import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:shuttle_tracker_backend/src/database.dart';

String _hash(String password) {
  final bytes = utf8.encode(password);
  return sha256.convert(bytes).toString();
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run bin/reset_password.dart <userId|email> <newPassword>');
    exit(2);
  }
  final idOrEmail = args[0];
  final newPassword = args.length > 1 ? args[1] : 'secret123';

  final db = Database();
  await db.connect();
  final hashed = _hash(newPassword);

  try {
    if (int.tryParse(idOrEmail) != null) {
      final userId = int.parse(idOrEmail);
      await db.query('UPDATE users SET password_hash = @hash WHERE user_id = @id', substitutionValues: {'hash': hashed, 'id': userId});
      print('Updated password for user_id=$userId');
    } else {
      final email = idOrEmail;
      await db.query('UPDATE users SET password_hash = @hash WHERE email = @email', substitutionValues: {'hash': hashed, 'email': email});
      print('Updated password for email=$email');
    }
  } catch (e, st) {
    stderr.writeln('Failed to update password: $e');
    stderr.writeln(st);
    exitCode = 1;
  }
  print('Done');
}

