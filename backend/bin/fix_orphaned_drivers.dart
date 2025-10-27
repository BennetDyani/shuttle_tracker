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
    // Find orphaned driver users
    print('Finding orphaned driver users...');
    final orphaned = await connection.query('''
      SELECT u.user_id, u.first_name, u.last_name, u.email 
      FROM users u 
      WHERE u.role_id = 3 
      AND NOT EXISTS (SELECT 1 FROM drivers d WHERE d.user_id = u.user_id)
      ORDER BY u.user_id
    ''');

    if (orphaned.isEmpty) {
      print('No orphaned driver users found. Nothing to fix.');
      return;
    }

    print('Found ${orphaned.length} orphaned driver users:\n');
    for (final row in orphaned) {
      print('  User ${row[0]}: ${row[1]} ${row[2]} (${row[3]})');
    }

    print('\nCreating driver records for orphaned users...\n');

    int fixed = 0;
    for (final row in orphaned) {
      final userId = row[0];
      final firstName = row[1];
      final lastName = row[2];
      final email = row[3];

      // Generate a license number
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final licenseNumber = 'DEV-LIC-$userId-$timestamp';

      try {
        await connection.query(
          'INSERT INTO drivers (user_id, license_number, phone_number) VALUES (@userId, @license, NULL)',
          substitutionValues: {
            'userId': userId,
            'license': licenseNumber,
          },
        );
        print('  ✓ Created driver record for User $userId ($firstName $lastName)');
        print('    License: $licenseNumber');
        fixed++;
      } catch (e) {
        print('  ✗ Failed to create driver record for User $userId: $e');
      }
    }

    print('\n=== Summary ===');
    print('Fixed $fixed out of ${orphaned.length} orphaned drivers.');

    // Verify the fix
    print('\nVerifying fix...');
    final driversAfter = await connection.query('SELECT COUNT(*) FROM drivers');
    final driverUsersAfter = await connection.query('SELECT COUNT(*) FROM users WHERE role_id = 3');
    print('Drivers table: ${driversAfter.first[0]} records');
    print('Driver users: ${driverUsersAfter.first[0]} users');

    if (driversAfter.first[0] == driverUsersAfter.first[0]) {
      print('\n✓ SUCCESS: All driver users now have driver records!');
    } else {
      print('\n✗ WARNING: Still have mismatched counts!');
    }

  } finally {
    await connection.close();
    print('\nConnection closed.');
  }
}

