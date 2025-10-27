import 'dart:io';
import 'package:postgres/postgres.dart' as pg;

void main() async {
  final dbHost = Platform.environment['DB_HOST'] ?? 'localhost';
  final dbPort = int.parse(Platform.environment['DB_PORT'] ?? '5432');
  final dbName = Platform.environment['DB_NAME'] ?? 'postgres';
  final dbUser = Platform.environment['DB_USER'] ?? 'postgres';
  final dbPassword = Platform.environment['DB_PASSWORD'] ?? '@B0837181632bb';

  print('Connecting to PostgreSQL at $dbHost:$dbPort/$dbName...');

  final connection = pg.PostgreSQLConnection(
    dbHost,
    dbPort,
    dbName,
    username: dbUser,
    password: dbPassword,
  );

  await connection.open();

  print('Connected successfully!\n');

  try {
    // Check drivers table
    print('=== DRIVERS TABLE ===');
    final drivers = await connection.query('SELECT driver_id, user_id, license_number, phone_number FROM drivers ORDER BY driver_id');
    print('Total drivers: ${drivers.length}');
    for (final row in drivers) {
      print('  Driver ${row[0]}: user_id=${row[1]}, license=${row[2]}, phone=${row[3] ?? "NULL"}');
    }
    print('');

    // Check users with role_id = 3 (drivers)
    print('=== USERS WITH DRIVER ROLE (role_id=3) ===');
    final driverUsers = await connection.query(
      'SELECT user_id, first_name, last_name, email, role_id FROM users WHERE role_id = 3 ORDER BY user_id'
    );
    print('Total driver users: ${driverUsers.length}');
    for (final row in driverUsers) {
      print('  User ${row[0]}: ${row[1]} ${row[2]} (${row[3]})');
    }
    print('');

    // Check if there are any orphaned users (driver role but no driver record)
    print('=== CHECKING FOR ORPHANED DRIVER USERS ===');
    final orphaned = await connection.query('''
      SELECT u.user_id, u.first_name, u.last_name, u.email 
      FROM users u 
      WHERE u.role_id = 3 
      AND NOT EXISTS (SELECT 1 FROM drivers d WHERE d.user_id = u.user_id)
      ORDER BY u.user_id
    ''');
    if (orphaned.isEmpty) {
      print('No orphaned driver users found.');
    } else {
      print('Found ${orphaned.length} orphaned driver users (have driver role but no driver record):');
      for (final row in orphaned) {
        print('  User ${row[0]}: ${row[1]} ${row[2]} (${row[3]})');
      }
    }
    print('');

    // Check roles table
    print('=== ROLES TABLE ===');
    final roles = await connection.query('SELECT * FROM roles ORDER BY role_id');
    for (final row in roles) {
      print('  Role ${row[0]}: ${row[1]}');
    }

  } finally {
    await connection.close();
    print('\nConnection closed.');
  }
}

