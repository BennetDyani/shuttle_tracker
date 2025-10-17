import 'dart:io';
import 'package:shuttle_tracker_backend/src/database.dart';

Future<void> main(List<String> args) async {
  stdout.writeln('[init_db] Starting DB initialization...');
  try {
    await Database().connect();
    stdout.writeln('[init_db] Schema creation attempted. If the DB was reachable, tables were created or already existed.');
  } catch (e, st) {
    stderr.writeln('[init_db] Failed to initialize DB: $e');
    stderr.writeln(st);
    exitCode = 1;
  }
}

