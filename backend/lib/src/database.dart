import 'package:postgres/postgres.dart';
import 'dart:io';

class Database {
  static final Database _instance = Database._internal();
  factory Database() => _instance;
  Database._internal();

  late final PostgreSQLConnection _connection;
  bool _connected = false;

  Future<void> connect() async {
    final skip = (Platform.environment['SKIP_DB'] ?? '').toLowerCase();
    final shouldSkip = skip == '1' || skip == 'true' || skip == 'yes';
    if (shouldSkip) {
      print('[Database] SKIP_DB is set — skipping DB connection for local testing.');
      _connected = false;
      return;
    }
    final host = Platform.environment['DB_HOST'] ?? 'localhost';
    final port = int.tryParse(Platform.environment['DB_PORT'] ?? '5432') ?? 5432;
    final databaseName = Platform.environment['DB_NAME'] ?? 'postgres';
    final username = Platform.environment['DB_USER'] ?? 'postgres';
    final password = Platform.environment['DB_PASSWORD'] ?? '@B0837181632bb';

    _connection = PostgreSQLConnection(
      host,
      port,
      databaseName,
      username: username,
      password: password,
    );
    await _connection.open();
    _connected = true;
    await _createTables();
  }

  /// Returns true if the DB connection was established.
  bool get isConnected => _connected;

  Future<void> _createTables() async {
    // Helper to run SQL and log any DB-level errors with the SQL included
    Future<void> exec(String sql) async {
      try {
        await _connection.query(sql);
      } catch (e, st) {
        stderr.writeln('[Database] Failed executing SQL:\n$sql\nError: $e\n$st');
        rethrow;
      }
    }

    final statements = <String>[
      '''
      CREATE TABLE IF NOT EXISTS roles (
        role_id SERIAL PRIMARY KEY,
        role_name VARCHAR(255) UNIQUE NOT NULL
      );
    ''',

      '''
      CREATE TABLE IF NOT EXISTS users (
        user_id SERIAL PRIMARY KEY,
        first_name VARCHAR(255) NOT NULL,
        last_name VARCHAR(255) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        role_id INTEGER REFERENCES roles(role_id),
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    ''',

      '''
        CREATE TABLE IF NOT EXISTS shuttle_status (
            status_id SERIAL PRIMARY KEY,
            status_name VARCHAR(255) NOT NULL
        );
    ''',

      '''
        CREATE TABLE IF NOT EXISTS shuttle_type (
            type_id SERIAL PRIMARY KEY,
            type_name VARCHAR(255) NOT NULL
        );
    ''',

      '''
      CREATE TABLE IF NOT EXISTS shuttles (
        shuttle_id SERIAL PRIMARY KEY,
        make VARCHAR(255) NOT NULL,
        model VARCHAR(255) NOT NULL,
        year INTEGER NOT NULL,
        capacity INTEGER NOT NULL,
        license_plate VARCHAR(255) UNIQUE NOT NULL,
        status_id INTEGER REFERENCES shuttle_status(status_id),
        type_id INTEGER REFERENCES shuttle_type(type_id)
      );
    ''',

      '''
      CREATE TABLE IF NOT EXISTS drivers (
        driver_id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(user_id) ON DELETE CASCADE,
        license_number VARCHAR(255) UNIQUE NOT NULL,
        phone_number VARCHAR(255)
      );
    ''',

      '''
      CREATE TABLE IF NOT EXISTS students (
        student_rec_id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(user_id) ON DELETE CASCADE,
        student_id VARCHAR(255) UNIQUE NOT NULL,
        phone_number VARCHAR(255),
        has_disability BOOLEAN DEFAULT FALSE,
        disability_type VARCHAR(255),
        requires_minibus BOOLEAN DEFAULT FALSE
      );
    ''',

      '''
      CREATE TABLE IF NOT EXISTS staff (
        staff_rec_id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(user_id) ON DELETE CASCADE,
        staff_id VARCHAR(255) UNIQUE NOT NULL
      );
    ''',

      '''
      CREATE TABLE IF NOT EXISTS routes (
        route_id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT
      );
    ''',

      '''
      CREATE TABLE IF NOT EXISTS stops (
        stop_id SERIAL PRIMARY KEY,
        route_id INTEGER REFERENCES routes(route_id) ON DELETE CASCADE,
        name VARCHAR(255) NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        "order" INTEGER NOT NULL
      );
    ''',

      '''
      CREATE TABLE IF NOT EXISTS schedules (
        schedule_id SERIAL PRIMARY KEY,
        route_id INTEGER REFERENCES routes(route_id) ON DELETE CASCADE,
        departure_time TIME NOT NULL,
        arrival_time TIME NOT NULL,
        day_of_week VARCHAR(255) NOT NULL
      );
    ''',

      '''
      CREATE TABLE IF NOT EXISTS driver_assignments (
        assignment_id SERIAL PRIMARY KEY,
        driver_id INTEGER REFERENCES drivers(driver_id) ON DELETE CASCADE,
        shuttle_id INTEGER REFERENCES shuttles(shuttle_id) ON DELETE CASCADE,
        schedule_id INTEGER REFERENCES schedules(schedule_id) ON DELETE CASCADE,
        assignment_date DATE NOT NULL
      );
    ''',

      '''
      CREATE TABLE IF NOT EXISTS complaint_status (
        status_id SERIAL PRIMARY KEY,
        status_name VARCHAR(255) NOT NULL
      );
    ''',

      '''
      CREATE TABLE IF NOT EXISTS complaints (
        complaint_id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(user_id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        description TEXT NOT NULL,
        status_id INTEGER REFERENCES complaint_status(status_id),
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    ''',

      '''
      CREATE TABLE IF NOT EXISTS notifications (
        notification_id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(user_id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        message TEXT NOT NULL,
        is_read BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    ''',

      '''
      CREATE TABLE IF NOT EXISTS feedback (
        feedback_id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(user_id) ON DELETE CASCADE,
        rating INTEGER NOT NULL,
        comment TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    ''',

      '''
      -- Stores device tokens registered by client apps so the server can target notifications
      CREATE TABLE IF NOT EXISTS user_devices (
        device_id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(user_id) ON DELETE CASCADE,
        device_token TEXT UNIQUE NOT NULL,
        platform VARCHAR(50),
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    ''',

      '''
      CREATE TABLE IF NOT EXISTS maintenance (
        maintenance_id SERIAL PRIMARY KEY,
        shuttle_id INTEGER REFERENCES shuttles(shuttle_id) ON DELETE CASCADE,
        report_date DATE NOT NULL,
        description TEXT NOT NULL,
        resolved BOOLEAN DEFAULT FALSE
      );
    ''',
    ];

    for (final s in statements) {
      await exec(s);
    }

    // Ensure unique semantics for seed data so ON CONFLICT works reliably
    final indexes = <String>[
      "CREATE UNIQUE INDEX IF NOT EXISTS ux_shuttle_status_name ON shuttle_status (status_name);",
      "CREATE UNIQUE INDEX IF NOT EXISTS ux_shuttle_type_name ON shuttle_type (type_name);",
      "CREATE UNIQUE INDEX IF NOT EXISTS ux_complaint_status_name ON complaint_status (status_name);",
      "CREATE UNIQUE INDEX IF NOT EXISTS ux_student_student_id ON students (student_id);",
      "CREATE UNIQUE INDEX IF NOT EXISTS ux_staff_staff_id ON staff (staff_id);",
      "CREATE UNIQUE INDEX IF NOT EXISTS ux_user_devices_token ON user_devices (device_token);",
    ];

    for (final i in indexes) {
      await exec(i);
    }

    // Ensure previous view is removed (avoids conflicts if old view used u.*)
    await exec('DROP VIEW IF EXISTS admins CASCADE;');

    // Provide a convenient view for admins so callers can query 'admins' like a table.
    await exec('''
      CREATE OR REPLACE VIEW admins AS
      SELECT
        u.user_id,
        u.first_name,
        u.last_name,
        u.email,
        u.password_hash,
        u.role_id,
        u.created_at,
        r.role_name AS role_name,
        s.staff_id AS staff_id
      FROM users u
      JOIN staff s ON u.user_id = s.user_id
      JOIN roles r ON u.role_id = r.role_id
      WHERE r.role_name = 'ADMIN';
    ''');
  }

  Future<PostgreSQLResult> query(String sql, {Map<String, dynamic>? substitutionValues}) {
    return _connection.query(sql, substitutionValues: substitutionValues);
  }

  /// Run a database transaction using the underlying PostgreSQL connection.
  /// This proxies the call to PostgreSQLConnection.transaction so callers can
  /// pass a callback that receives a PostgreSQLExecutionContext.
  Future<dynamic> transaction(Future<dynamic> Function(PostgreSQLExecutionContext ctx) callback, {int? commitTimeoutInSeconds}) {
    return _connection.transaction(callback, commitTimeoutInSeconds: commitTimeoutInSeconds);
  }
}
