import 'dart:convert';
import 'package:shuttle_tracker_backend/src/database.dart';

Future<void> main(List<String> args) async {
  try {
    final db = Database();
    await db.connect();

    print('Connected: ${db.isConnected}');

    final users = await db.query("SELECT user_id, email, role_id FROM users WHERE email = @email", substitutionValues: {'email': 'kabelomomo@hgtsadmin.cput.com'});
    print('USERS:');
    for (final r in users) {
      print(jsonEncode(r.toColumnMap()));
    }

    final staff = await db.query("SELECT * FROM staff WHERE user_id IN (SELECT user_id FROM users WHERE email = @email)", substitutionValues: {'email': 'kabelomomo@hgtsadmin.cput.com'});
    print('STAFF:');
    for (final r in staff) {
      print(jsonEncode(r.toColumnMap()));
    }

    // Try the admins view if exists
    try {
      final admins = await db.query('SELECT * FROM admins WHERE email = @email', substitutionValues: {'email': 'kabelomomo@hgtsadmin.cput.com'});
      print('ADMINS_VIEW:');
      for (final r in admins) print(jsonEncode(r.toColumnMap()));
    } catch (e) {
      print('ADMINS_VIEW: error -> $e');
    }

    await Future.delayed(Duration(milliseconds: 100));
    print('Done');
  } catch (e, st) {
    print('Error connecting/querying DB: $e');
    print(st);
  }
}

