import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';
import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart' as pg;


import 'package:shuttle_tracker_backend/src/database.dart';
import 'package:shuttle_tracker_backend/src/config.dart';
import 'package:shuttle_tracker_backend/src/firebase_admin.dart';

// Database instance
final db = Database();
final firebaseAdmin = FirebaseAdminService();

// In-memory set of connected WebSocket clients to broadcast location updates.
final Set<WebSocket> _wsClients = <WebSocket>{};

void _broadcastLocationMessage(Map<String, dynamic> msg) {
  final text = jsonEncode(msg);
  for (final ws in List<WebSocket>.from(_wsClients)) {
    try {
      ws.add(text);
    } catch (e) {
      try {
        ws.close();
      } catch (_) {}
      _wsClients.remove(ws);
    }
  }
}

// Core app router (unprefixed)
final _router = Router()
  // General
  ..get('/', _rootHandler)
  ..get('/echo/<message>', _echoHandler)
  ..get('/health', _healthHandler)
  // Auth
  ..post('/auth/login', _loginHandler)
  ..post('/auth/staff-login', _staffLoginHandler)
  ..post('/auth/signup', _signupHandler)
  // Users
  ..post('/users/create', _createUserHandler)
  ..put('/users/<id>', _updateUserHandler)
  ..get('/users/read/<id>', _readUserByIdHandler)
  ..get('/users/readByEmail/<email>', _readUserByEmailHandler)
  ..delete('/users/delete/<id>', _deleteUserByIdHandler)
  ..delete('/users/deleteByEmail/<email>', _deleteUserByEmailHandler)
  ..get('/users/getAll', _getAllUsersHandler)
  // Admins
  ..post('/admins/create', _createAdminHandler)
  ..put('/admins/update', _updateAdminHandler)
  ..get('/admins/read/<id>', _readAdminByIdHandler)
  ..get('/admins/readByEmail/<email>', _readAdminByEmailHandler)
  ..delete('/admins/delete/<id>', _deleteAdminByIdHandler)
  ..delete('/admins/deleteByEmail/<email>', _deleteAdminByEmailHandler)
  ..get('/admins/getAll', _getAllAdminsHandler)
  ..post('/admins/promote', _promoteAdminHandler)
  // Drivers
  ..post('/drivers/create', _createDriverHandler)
  ..put('/drivers/update/<id>', _updateDriverHandler)
  ..get('/drivers/read/<id>', _readDriverByIdHandler)
  ..get('/drivers/readByEmail/<email>', _readDriverByEmailHandler)
  ..delete('/drivers/delete/<id>', _deleteDriverByIdHandler)
  ..delete('/drivers/deleteByEmail/<email>', _deleteDriverByEmailHandler)
  ..get('/drivers/getAll', _getAllDriversHandler)
  // Shuttles
  ..post('/shuttles/create', _createShuttleHandler)
  ..put('/shuttles/update/<id>', _updateShuttleHandler)
  ..put('/shuttles/<id>/status', _updateShuttleStatusHandler)
  ..get('/shuttles/read/<id>', _readShuttleByIdHandler)
  ..get('/shuttles/readByPlate/<plate>', _readShuttleByPlateHandler)
  ..delete('/shuttles/delete/<id>', _deleteShuttleByIdHandler)
  ..delete('/shuttles/deleteByPlate/<plate>', _deleteShuttleByPlateHandler)
  ..get('/shuttles/getAll', _getAllShuttlesHandler)
  ..get('/shuttles/statuses', _getShuttleStatusesHandler)
  ..get('/shuttles/types', _getShuttleTypesHandler)
  // Driver Assignments
  ..post('/assignments/create', _createDriverAssignmentHandler)
  ..post('/dev/seedDriver/<userId>', _seedDriverFromUserHandler)
  ..get('/assignments/read/<id>', _readDriverAssignmentByIdHandler)
  ..get('/assignments/driver/<driverId>', _readAssignmentsByDriverIdHandler)
  ..get('/assignments/getAll', _getAllDriverAssignmentsHandler)
  ..put('/assignments/update/<id>', _updateDriverAssignmentHandler)
  ..delete('/assignments/delete/<id>', _deleteDriverAssignmentByIdHandler)
  // Complaints
  ..post('/complaints/create', _createComplaintHandler)
  ..get('/complaints/getAll', _getAllComplaintsHandler)
  ..get('/complaints/read/<id>', _getComplaintByIdHandler)
  ..put('/complaints/update/<id>', _updateComplaintHandler)
  // Routes
  ..post('/routes/create', _createRouteHandler)
  ..get('/routes/getAll', _getAllRoutesHandler)
  ..get('/routes/read/<id>', _getRouteByIdHandler)
  ..put('/routes/update/<id>', _updateRouteHandler)
  ..delete('/routes/delete/<id>', _deleteRouteHandler)
  ..post('/routes/<id>/stops', _addStopToRouteHandler)
  ..post('/stops', _createStopHandler)
  ..get('/routes/<routeId>/stops', _getRouteStopsByRouteIdHandler)
  //Schedules
  ..post('/schedules/create', _createScheduleHandler)
  ..get('/schedules/read/<id>', _getScheduleByIdHandler)
  ..get('/schedules/driver/<driverId>', _getScheduleByDriverIdHandler)
  ..get('/schedules/getAll', _getAllSchedulesHandler)
  ..put('/schedules/update/<id>', _updateScheduleHandler)
  ..delete('/schedules/delete/<id>', _deleteScheduleHandler)
  // Notifications
  ..post('/notifications/create', _createNotificationHandler)
  ..post('/notifications/batchCreate', _batchCreateNotificationsHandler)
  ..put('/notifications/update', _updateNotificationHandler)
  ..get('/notifications/read/<id>', _readNotificationByIdHandler)
  ..delete('/notifications/delete/<id>', _deleteNotificationByIdHandler)
  ..get('/notifications/getAll', _getAllNotificationsHandler)
  // Device tokens (clients should register their FCM device tokens here)
  ..post('/devices/register', _registerDeviceHandler)
  ..delete('/devices/delete/<token>', _deleteDeviceByTokenHandler)
  ..get('/devices/user/<userId>', _getDevicesByUserHandler)
  ..get('/devices/getAll', _getAllDevicesHandler)
  ..post('/notifications/sendTest', _sendTestNotificationHandler)
  // Feedbacks
  ..post('/feedbacks/create', _createFeedbackHandler)
  ..put('/feedbacks/update', _updateFeedbackHandler)
  ..get('/feedbacks/read/<id>', _readFeedbackByIdHandler)
  ..delete('/feedbacks/delete/<id>', _deleteFeedbackByIdHandler)
  ..get('/feedbacks/getAll', _getAllFeedbacksHandler)
  // Maintenance
  ..post('/maintenanceReports/create', _createMaintenanceReportHandler)
  // Location
  ..post('/location/update-location', _updateLocationHandler)
  ..get('/location/recent', _getRecentLocationsHandler)
  // WebSocket endpoint for STOMP/real-time push (simple plain WebSocket broadcast)
  ..get('/ws', webSocketHandler((WebSocket ws) {
    // Add client and remove on done
    _wsClients.add(ws);
    ws.done.then((_) {
      _wsClients.remove(ws);
    });
  }))
;

// Expose routes under '/', '/api/', and '/api/v1/'
final rootRouter = Router()
  ..mount('/', _router)
  ..mount('/api/', _router)
  ..mount('/api/v1/', _router);

String _hashPassword(String password) {
  final bytes = utf8.encode(password);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

// JSON helper: encodes DateTime (and nested structures) safely
String _jsonEncodeSafe(Object? data) {
  final encoder = JsonEncoder.withIndent(null, (obj) {
    if (obj is DateTime) return obj.toIso8601String();
    return obj; // let default encoder handle other types
  });
  return encoder.convert(data);
}

// General Handlers
Response _rootHandler(Request req) {
  return Response.ok('Hello, World!\n');
}

Response _echoHandler(Request request) {
  final message = request.params['message'];
  return Response.ok('$message\n');
}

// Health handler (used by the router)
Future<Response> _healthHandler(Request request) async {
  try {
    // quick DB check only if connected
    if (db.isConnected) {
      await db.query('SELECT 1');
    }
    final status = firebaseAdmin.status;
    return Response.ok(_jsonEncodeSafe({'ok': true, 'db_connected': db.isConnected, 'firebase': status}));
  } catch (e) {
    final status = firebaseAdmin.status;
    return Response.internalServerError(body: _jsonEncodeSafe({'ok': false, 'error': e.toString(), 'firebase': status}));
  }
}

// Auth Handlers
Future<Response> _loginHandler(Request request) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  final email = params['email'];
  final password = params['password'];

  final studentRegex = RegExp(r'^\d{9}@mycput\.ac\.za$');

  if (!studentRegex.hasMatch(email)) {
    return Response.forbidden(_jsonEncodeSafe({'error': 'Invalid student email format'}));
  }

  try {
    final result = await db.query(
      'SELECT u.*, r.role_name FROM users u JOIN roles r ON u.role_id = r.role_id WHERE u.email = @email AND u.password_hash = @password',
      substitutionValues: {'email': email, 'password': _hashPassword(password)},
    );

    if (result.isNotEmpty) {
      final user = result.first.toColumnMap();
      final claimSet = JwtClaim(
        subject: user['user_id'].toString(),
        issuer: 'shuttle_tracker',
        otherClaims: <String, dynamic>{
          'role': user['role_name'],
        },
        maxAge: const Duration(hours: 24),
      );
      final token = issueJwtHS256(claimSet, jwtSecret);
      // Provide explicit top-level role and userId fields so clients
      // (especially the Flutter app) can reliably parse login results.
      return Response.ok(_jsonEncodeSafe({
        'token': token,
        'user': user,
        'role': user['role_name'],
        'userId': user['user_id']
      }));
    } else {
      return Response.forbidden(_jsonEncodeSafe({'error': 'Invalid credentials'}));
    }
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _staffLoginHandler(Request request) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  // Accept either email or staffId (frontend may send staffId)
  final emailOrId = (params['email'] ?? params['staffId'])?.toString();
  final password = params['password'];

  if (emailOrId == null || password == null) {
    return Response.badRequest(body: _jsonEncodeSafe({'error': 'Missing credentials'}));
  }

  final adminRegex = RegExp(r'^[a-zA-Z\.]+@hgtsadmin\.cput\.com$');
  final driverRegex = RegExp(r'^[a-zA-Z\.]+@hgtsdriver\.cput\.com$');

  // Only enforce email format if this looks like an email
  if (emailOrId.contains('@') && !adminRegex.hasMatch(emailOrId) && !driverRegex.hasMatch(emailOrId)) {
    return Response.forbidden(_jsonEncodeSafe({'error': 'Invalid staff email format'}));
  }

  try {
    // Determine whether the caller supplied an email or a staffId
    final bool isEmail = emailOrId.contains('@');
    final result = await db.query(
      isEmail
          ? 'SELECT u.*, r.role_name FROM users u JOIN roles r ON u.role_id = r.role_id WHERE u.email = @identifier AND u.password_hash = @password'
          : 'SELECT u.*, r.role_name FROM users u JOIN roles r ON u.role_id = r.role_id JOIN staff s ON s.user_id = u.user_id WHERE s.staff_id = @identifier AND u.password_hash = @password',
      substitutionValues: {'identifier': emailOrId, 'password': _hashPassword(password)},
    );

    if (result.isNotEmpty) {
      final user = result.first.toColumnMap();
      final claimSet = JwtClaim(
        subject: user['user_id'].toString(),
        issuer: 'shuttle_tracker',
        otherClaims: <String, dynamic>{
          'role': user['role_name'],
        },
        maxAge: const Duration(hours: 24),
      );
      final token = issueJwtHS256(claimSet, jwtSecret);
      // Provide explicit top-level role and userId fields so clients
      // (especially the Flutter app) can reliably parse login results.
      return Response.ok(_jsonEncodeSafe({
        'token': token,
        'user': user,
        'role': user['role_name'],
        'userId': user['user_id']
      }));
    } else {
      return Response.forbidden(_jsonEncodeSafe({'error': 'Invalid credentials'}));
    }
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

// New: allow students to signup (self-register)
Future<Response> _signupHandler(Request request) async {
  if (!db.isConnected) {
    return Response(503, body: _jsonEncodeSafe({'error': 'Database is not connected'}));
  }

  final body = await request.readAsString();
  final params = jsonDecode(body);
  final firstName = (params['firstName'] ?? params['name'])?.toString().trim();
  final lastName = (params['lastName'] ?? params['surname'])?.toString().trim();
  final email = params['email']?.toString().trim();
  final rawPassword = params['password']?.toString();

  if (firstName == null || firstName.isEmpty || lastName == null || lastName.isEmpty) {
    return Response.badRequest(body: _jsonEncodeSafe({'error': 'Missing first name or last name'}));
  }
  if (email == null || email.isEmpty || rawPassword == null || rawPassword.isEmpty) {
    return Response.badRequest(body: _jsonEncodeSafe({'error': 'Missing email or password'}));
  }

  final studentRegex = RegExp(r'^\d{9}@mycput\.ac\.za$');
  if (!studentRegex.hasMatch(email)) {
    return Response.badRequest(body: _jsonEncodeSafe({'error': 'Only CPUT student emails (NNNNNNNNN@mycput.ac.za) are allowed to signup here'}));
  }

  try {
    final result = await db.transaction((ctx) async {
      // Ensure STUDENT or DISABLED_STUDENT role exists
      final providedRole = (params['role']?.toString().trim().toUpperCase());
      final role = (providedRole == 'DISABLED_STUDENT') ? 'DISABLED_STUDENT' : 'STUDENT';

      final roleResult = await ctx.query(
        'SELECT role_id FROM roles WHERE role_name = @roleName',
        substitutionValues: {'roleName': role},
      );

      if (roleResult.isEmpty) {
        throw Exception('Role not found');
      }
      final roleId = roleResult.first.toColumnMap()['role_id'];

      // Insert user
      final userResult = await ctx.query(
        'INSERT INTO users (first_name, last_name, email, password_hash, role_id) VALUES (@firstName, @lastName, @email, @password, @roleId) RETURNING user_id',
        substitutionValues: {
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'password': _hashPassword(rawPassword),
          'roleId': roleId,
        },
      );
      final userId = userResult.first.toColumnMap()['user_id'];

      // Insert student specific row
      final studentId = email.split('@').first; // student number
      final phoneNumber = (params['phone_number'] ?? params['phoneNumber'])?.toString().trim();
      final hasDisability = (params.containsKey('has_disability') ? params['has_disability'] : params['hasDisability']) ?? false;
      final disabilityType = params['disability_type'] ?? params['disabilityType'];
      final requiresMinibus = params['requires_minibus'] ?? params['requiresMinibus'] ?? false;

      await ctx.query(
        '''
        INSERT INTO students (user_id, student_id, phone_number, has_disability, disability_type, requires_minibus)
        VALUES (@userId, @studentId, @phone, @hasDisability, @disabilityType, @requiresMinibus)
        ''',
        substitutionValues: {
          'userId': userId,
          'studentId': studentId,
          'phone': phoneNumber,
          'hasDisability': hasDisability,
          'disabilityType': disabilityType,
          'requiresMinibus': requiresMinibus,
        },
      );

      // Return created user row joined with role name
      final finalUserResult = await ctx.query('SELECT u.*, r.role_name FROM users u JOIN roles r ON u.role_id = r.role_id WHERE u.user_id = @id', substitutionValues: {'id': userId});
      return finalUserResult.first.toColumnMap();
    });

    // Issue JWT for the newly created user so the client can be logged in immediately
    final user = result;
    final claimSet = JwtClaim(
      subject: user['user_id'].toString(),
      issuer: 'shuttle_tracker',
      otherClaims: <String, dynamic>{
        'role': user['role_name'],
      },
      maxAge: const Duration(hours: 24),
    );
    final token = issueJwtHS256(claimSet, jwtSecret);

    return Response.ok(_jsonEncodeSafe({
      'token': token,
      'user': user,
      'role': user['role_name'],
      'userId': user['user_id']
    }));
  } on pg.PostgreSQLException catch (e, st) {
    stderr.writeln('[_signupHandler] PostgreSQLException: ${e.code} ${e.message}\n$st');
    if (e.code == '23505') { // unique_violation
      return Response(409, body: _jsonEncodeSafe({'error': 'A user with this email or ID already exists'}));
    }
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Database error', 'code': e.code}));
  } catch (e, st) {
    stderr.writeln('[_signupHandler] Unexpected error: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'An unexpected error occurred', 'message': e.toString()}));
  }
}

// User Handlers
Future<Response> _createUserHandler(Request request) async {
  if (!db.isConnected) {
    return Response(503, body: _jsonEncodeSafe({'error': 'Database is not connected'}));
  }
  final body = await request.readAsString();
  final params = jsonDecode(body);
  final firstName = (params['firstName'] ?? params['name'])?.toString().trim();
  final lastName = (params['lastName'] ?? params['surname'])?.toString().trim();
  final email = params['email']?.toString().trim();
  final rawPassword = params['password']?.toString();

  if (firstName == null || firstName.isEmpty || lastName == null || lastName.isEmpty) {
    return Response.badRequest(body: _jsonEncodeSafe({'error': 'Missing first name or last name'}));
  }
  if (email == null || email.isEmpty || rawPassword == null || rawPassword.isEmpty) {
    return Response.badRequest(body: _jsonEncodeSafe({'error': 'Missing email or password'}));
  }

  final providedRole = (params['role']?.toString().trim().toUpperCase());
  String? role;
  final studentRegex = RegExp(r'^\d{9}@mycput\.ac\.za$');
  final adminRegex = RegExp(r'^[a-zA-Z\.]+@hgtsadmin\.cput\.com$');
  final driverRegex = RegExp(r'^[a-zA-Z\.]+@hgtsdriver\.cput\.com$');

  if (studentRegex.hasMatch(email)) {
    role = (providedRole == 'DISABLED_STUDENT') ? 'DISABLED_STUDENT' : 'STUDENT';
  } else if (adminRegex.hasMatch(email)) {
    role = 'ADMIN';
  } else if (driverRegex.hasMatch(email)) {
    role = 'DRIVER';
  } else if (providedRole == 'STUDENT' || providedRole == 'DISABLED_STUDENT' || providedRole == 'ADMIN' || providedRole == 'DRIVER') {
    role = providedRole;
  }

  if (role == null) {
    return Response.badRequest(body: _jsonEncodeSafe({'error': 'Invalid email format and role not provided/recognized'}));
  }

  try {
    // Use a transaction to ensure atomicity across multiple table inserts
    final result = await db.transaction((ctx) async {
      // Step 1: Get the role_id from the 'roles' table
      final roleResult = await ctx.query(
        'SELECT role_id FROM roles WHERE role_name = @roleName',
        substitutionValues: {'roleName': role},
      );

      if (roleResult.isEmpty) {
        throw Exception('Role not found'); // This will trigger a rollback
      }
      final roleId = roleResult.first.toColumnMap()['role_id'];

      // Step 2: Create the user in the 'users' table and get the new user_id
      final userResult = await ctx.query(
        'INSERT INTO users (first_name, last_name, email, password_hash, role_id) VALUES (@firstName, @lastName, @email, @password, @roleId) RETURNING user_id',
        substitutionValues: {
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'password': _hashPassword(rawPassword),
          'roleId': roleId,
        },
      );
      final userId = userResult.first.toColumnMap()['user_id'];

      // Step 3: Insert role-specific data into the appropriate table
      if (role == 'STUDENT' || role == 'DISABLED_STUDENT') {
        final studentId = email.split('@').first; // Extract student number from email
        // Accept either snake_case or camelCase field names from frontend
        final phoneNumber = (params['phone_number'] ?? params['phoneNumber'])?.toString().trim();
        final hasDisability = role == 'DISABLED_STUDENT';
        final disabilityType = params['disability_type'] ?? params['disabilityType'];
        final requiresMinibus = params['requires_minibus'] ?? params['requiresMinibus'] ?? false;

        await ctx.query(
          '''
          INSERT INTO students (user_id, student_id, phone_number, has_disability, disability_type, requires_minibus)
          VALUES (@userId, @studentId, @phone, @hasDisability, @disabilityType, @requiresMinibus)
          ''',
          substitutionValues: {
            'userId': userId,
            'studentId': studentId,
            'phone': phoneNumber,
            'hasDisability': hasDisability,
            'disabilityType': disabilityType, // Pass from frontend
            'requiresMinibus': requiresMinibus, // Pass from frontend
          },
        );
      } else if (role == 'ADMIN' || role == 'DRIVER') {
        // Accept both snake_case and camelCase from clients
        final staffId = (params['staff_id'] ?? params['staffId'])?.toString().trim();
        if (staffId == null || staffId.isEmpty) {
          throw Exception('Staff ID is required for staff registration');
        }

        await ctx.query(
          'INSERT INTO staff (user_id, staff_id) VALUES (@userId, @staffId)',
          substitutionValues: {
            'userId': userId,
            'staffId': staffId,
          },
        );
      }

      // Transaction successful, return the newly created user data
      final finalUserResult = await ctx.query('SELECT u.*, r.role_name FROM users u JOIN roles r ON u.role_id = r.role_id WHERE u.user_id = @id', substitutionValues: {'id': userId});
      return finalUserResult.first.toColumnMap();
    });

    return Response.ok(_jsonEncodeSafe({
      'message': 'User created successfully',
      'user': result,
    }));
  } on pg.PostgreSQLException catch (e, st) {
    stderr.writeln('[_createUserHandler] PostgreSQLException: ${e.code} ${e.message}\n$st');
    if (e.code == '23505') { // unique_violation
      return Response(409, body: _jsonEncodeSafe({'error': 'A user with this email or ID already exists'}));
    }
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Database error', 'code': e.code}));
  } catch (e, st) {
    stderr.writeln('[_createUserHandler] Unexpected error: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'An unexpected error occurred', 'message': e.toString()}));
  }
}

Future<Response> _updateUserHandler(Request request, String id) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  final userId = int.tryParse(id);

  if (userId == null) {
    return Response.badRequest(body: _jsonEncodeSafe({'error': 'Invalid user ID format'}));
  }

  try {
    // Use a transaction to handle updates across multiple tables
    final result = await db.transaction((ctx) async {
      // Step 1: Update the base 'users' table
      final userUpdateResult = await ctx.query(
        'UPDATE users SET first_name = @firstName, last_name = @lastName, email = @email WHERE user_id = @id RETURNING *',
        substitutionValues: {
          'id': userId,
          'firstName': params['firstName'],
          'lastName': params['lastName'],
          'email': params['email'],
        },
      );

      if (userUpdateResult.isEmpty) {
        throw Exception('User not found'); // This will roll back the transaction
      }

      final updatedUser = userUpdateResult.first.toColumnMap();

      // Step 2: Check for and update role-specific tables if data is provided

      // Check for student updates
      if (params.containsKey('phone_number') || params.containsKey('phoneNumber') || params.containsKey('has_disability') || params.containsKey('hasDisability') || params.containsKey('disability_type') || params.containsKey('disabilityType') || params.containsKey('requires_minibus') || params.containsKey('requiresMinibus')) {
        // Accept both snake_case and camelCase from clients
        final phone = (params['phone_number'] ?? params['phoneNumber'])?.toString();
        final hasDisability = (params.containsKey('has_disability') ? params['has_disability'] : params['hasDisability']);
        final disabilityType = params['disability_type'] ?? params['disabilityType'];
        final requiresMinibus = params.containsKey('requires_minibus') ? params['requires_minibus'] : params['requiresMinibus'];

        await ctx.query(
            'UPDATE students SET phone_number = @phone, has_disability = @hasDisability, disability_type = @disabilityType, requires_minibus = @requiresMinibus WHERE user_id = @userId',
            substitutionValues: {
              'userId': userId,
              'phone': phone,
              'hasDisability': hasDisability,
              'disabilityType': disabilityType,
              'requiresMinibus': requiresMinibus,
            }
        );
      }

      // Check for staff updates
      if (params.containsKey('staff_id') || params.containsKey('staffId')) {
        final staffId = (params['staff_id'] ?? params['staffId'])?.toString().trim();
        if (staffId != null && staffId.isNotEmpty) {
          await ctx.query(
              'UPDATE staff SET staff_id = @staffId WHERE user_id = @userId',
              substitutionValues: {
                'userId': userId,
                'staffId': staffId,
              }
          );
        }
      }

      // Return the updated user data from the 'users' table
      return updatedUser;
    });

    return Response.ok(_jsonEncodeSafe({
      'message': 'User updated successfully',
      'user': result,
    }));
  } on Exception catch (e) {
    if (e.toString().contains('User not found')) {
      return Response.notFound(_jsonEncodeSafe({'error': 'User not found'}));
    }
    return Response.internalServerError(body: _jsonEncodeSafe({'error': e.toString()}));
  }
  catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}



Future<Response> _readUserByIdHandler(Request request, String id) async {
  try {
    final result = await db.query(
      '''
      SELECT u.*, r.role_name,
             s.staff_id AS staff_id,
             st.student_id AS student_id,
             st.phone_number AS student_phone,
             st.has_disability AS student_has_disability,
             st.disability_type AS student_disability_type,
             st.requires_minibus AS student_requires_minibus
      FROM users u
      JOIN roles r ON u.role_id = r.role_id
      LEFT JOIN staff s ON s.user_id = u.user_id
      LEFT JOIN students st ON st.user_id = u.user_id
      WHERE u.user_id = @id
      ''',
      substitutionValues: {'id': int.parse(id)},
    );

    if (result.isNotEmpty) {
      return Response.ok(_jsonEncodeSafe(result.first.toColumnMap()));
    } else {
      return Response.notFound(_jsonEncodeSafe({'error': 'User not found'}));
    }
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _readUserByEmailHandler(Request request, String email) async {
  try {
    final result = await db.query('SELECT * FROM users WHERE email = @email', substitutionValues: {'email': email});
    if (result.isNotEmpty) {
      return Response.ok(_jsonEncodeSafe(result.first.toColumnMap()));
    } else {
      return Response.notFound(_jsonEncodeSafe({'error': 'User not found'}));
    }
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _deleteUserByIdHandler(Request request, String id) async {
  try {
    await db.query('DELETE FROM users WHERE user_id = @id', substitutionValues: {'id': int.parse(id)});
    return Response.ok(_jsonEncodeSafe({'message': 'User deleted successfully'}));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _deleteUserByEmailHandler(Request request, String email) async {
  try {
    await db.query('DELETE FROM users WHERE email = @email', substitutionValues: {'email': email});
    return Response.ok(_jsonEncodeSafe({'message': 'User deleted successfully'}));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _getAllUsersHandler(Request request) async {
  try {
    // Return user rows joined with roles and optional staff/student info
    final result = await db.query(
      '''
      SELECT u.*, r.role_name,
             s.staff_id AS staff_id,
             st.phone_number AS student_phone,
             st.has_disability AS student_has_disability,
             st.disability_type AS student_disability_type,
             st.requires_minibus AS student_requires_minibus
      FROM users u
      JOIN roles r ON u.role_id = r.role_id
      LEFT JOIN staff s ON s.user_id = u.user_id
      LEFT JOIN students st ON st.user_id = u.user_id
      ''',
    );

    return Response.ok(_jsonEncodeSafe(result.map((row) => row.toColumnMap()).toList()));
   } catch (e) {
     return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
   }
}


// Admin Handlers
Future<Response> _createAdminHandler(Request request) async {
  return Response.ok(_jsonEncodeSafe({'message': 'Admin created successfully'}));
}

Future<Response> _updateAdminHandler(Request request) async {
  return Response.ok(_jsonEncodeSafe({'message': 'Admin updated successfully'}));
}

Response _readAdminByIdHandler(Request request, String id) {
  return Response.ok(_jsonEncodeSafe({'message': 'Details for admin $id'}));
}

Response _readAdminByEmailHandler(Request request, String email) {
  return Response.ok(_jsonEncodeSafe({'message': 'Details for admin $email'}));
}

Response _deleteAdminByIdHandler(Request request, String id) {
  return Response.ok(_jsonEncodeSafe({'message': 'Admin $id deleted'}));
}

Response _deleteAdminByEmailHandler(Request request, String email) {
  return Response.ok(_jsonEncodeSafe({'message': 'Admin with email $email deleted'}));
}

Future<Response> _getAllAdminsHandler(Request request) async {
  try {
    // Use the admins view for a concise admin listing (includes staff_id)
    final result = await db.query("SELECT * FROM admins");
    return Response.ok(_jsonEncodeSafe(result.map((row) => row.toColumnMap()).toList()));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _promoteAdminHandler(Request request) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  final staffId = (params['staffId'] ?? params['staff_id'])?.toString().trim();
  final userIdInput = params['userId'] ?? params['user_id'];
  final email = params['email']?.toString().trim();

  if (staffId == null || staffId.isEmpty) {
    return Response.badRequest(body: _jsonEncodeSafe({'error': 'staffId is required'}));
  }

  try {
    final result = await db.transaction((ctx) async {
      int userId;
      if (userIdInput != null) {
        userId = int.parse(userIdInput.toString());
      } else if (email != null && email.isNotEmpty) {
        final ures = await ctx.query('SELECT user_id FROM users WHERE email = @email', substitutionValues: {'email': email});
        if (ures.isEmpty) throw Exception('User not found');
        userId = ures.first.toColumnMap()['user_id'];
      } else {
        throw Exception('Either userId or email must be provided');
      }

      // Verify the user exists and has ADMIN role
      final roleRes = await ctx.query('SELECT r.role_name FROM roles r JOIN users u ON u.role_id = r.role_id WHERE u.user_id = @id', substitutionValues: {'id': userId});
      if (roleRes.isEmpty) throw Exception('User not found');
      final roleName = roleRes.first.toColumnMap()['role_name'];
      if (roleName != 'ADMIN') throw Exception('User is not an ADMIN');

      // Insert staff row
      final insertRes = await ctx.query('INSERT INTO staff (user_id, staff_id) VALUES (@userId, @staffId) RETURNING *',
        substitutionValues: {'userId': userId, 'staffId': staffId});
      return insertRes.first.toColumnMap();
    });

    return Response.ok(_jsonEncodeSafe({'message': 'User promoted to staff', 'staff': result}));
  } on pg.PostgreSQLException catch (e) {
    if (e.code == '23505') {
      return Response(409, body: _jsonEncodeSafe({'error': 'staff_id already exists'}));
    }
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Database error', 'code': e.code}));
  } catch (e) {
    return Response.badRequest(body: _jsonEncodeSafe({'error': e.toString()}));
  }
}
// Driver Handlers
Future<Response> _createDriverHandler(Request request) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  final email = params['email'];

  final driverRegex = RegExp(r'^[a-zA-Z\.]+@hgtsdriver\.cput\.com$');

  if (!driverRegex.hasMatch(email)) {
    return Response.badRequest(body: _jsonEncodeSafe({'error': 'Invalid driver email format'}));
  }

  try {
    final userResult = await db.query(
      'INSERT INTO users (first_name, last_name, email, password_hash, role_id) VALUES (@firstName, @lastName, @email, @password, (SELECT role_id FROM roles WHERE role_name = \'DRIVER\')) RETURNING *',
      substitutionValues: {
        'firstName': params['firstName'],
        'lastName': params['lastName'],
        'email': email,
        'password': _hashPassword(params['password']),
      },
    );
    final userId = userResult.first.toColumnMap()['user_id'];

    final driverResult = await db.query('INSERT INTO drivers (user_id, license_number, phone_number) VALUES (@userId, @license, @phone) RETURNING *',
    substitutionValues: {
      'userId': userId,
      'license': params['licenseNumber'],
      'phone': params['phoneNumber']
    });

    return Response.ok(_jsonEncodeSafe({
      'message': 'Driver created successfully',
      'driver': driverResult.first.toColumnMap(),
    }));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _updateDriverHandler(Request request, String id) async {
    final body = await request.readAsString();
  final params = jsonDecode(body);

  try {
    final result = await db.query(
      'UPDATE drivers SET license_number = @license, phone_number = @phone WHERE driver_id = @id RETURNING *',
      substitutionValues: {
        'id': int.parse(id),
        'license': params['licenseNumber'],
        'phone': params['phoneNumber'],
      },
    );
    return Response.ok(_jsonEncodeSafe({
      'message': 'Driver updated successfully',
      'driver': result.first.toColumnMap(),
    }));
  }catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _readDriverByIdHandler(Request request, String id) async {
  try {
    final result = await db.query('SELECT * FROM drivers WHERE driver_id = @id', substitutionValues: {'id': int.parse(id)});
    if (result.isNotEmpty) {
      return Response.ok(_jsonEncodeSafe(result.first.toColumnMap()));
    } else {
      return Response.notFound(_jsonEncodeSafe({'error': 'Driver not found'}));
    }
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _readDriverByEmailHandler(Request request, String email) async {
  try {
    final result = await db.query('SELECT d.* FROM drivers d JOIN users u ON d.user_id = u.user_id WHERE u.email = @email', substitutionValues: {'email': email});
    if (result.isNotEmpty) {
      return Response.ok(_jsonEncodeSafe(result.first.toColumnMap()));
    } else {
      return Response.notFound(_jsonEncodeSafe({'error': 'Driver not found'}));
    }
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _deleteDriverByIdHandler(Request request, String id) async {
  try {
    await db.query('DELETE FROM drivers WHERE driver_id = @id', substitutionValues: {'id': int.parse(id)});
    return Response.ok(_jsonEncodeSafe({'message': 'Driver deleted successfully'}));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _deleteDriverByEmailHandler(Request request, String email) async {
  try {
    final result = await db.query('SELECT d.driver_id FROM drivers d JOIN users u ON d.user_id = u.user_id WHERE u.email = @email', substitutionValues: {'email': email});
    if (result.isNotEmpty) {
      final driverId = result.first.toColumnMap()['driver_id'];
      await db.query('DELETE FROM drivers WHERE driver_id = @id', substitutionValues: {'id': driverId});
      await db.query('DELETE FROM users WHERE email = @email', substitutionValues: {'email': email});
      return Response.ok(_jsonEncodeSafe({'message': 'Driver deleted successfully'}));
    } else {
      return Response.notFound(_jsonEncodeSafe({'error': 'Driver not found'}));
    }
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _getAllDriversHandler(Request request) async {
    try {
    final result = await db.query("SELECT * FROM drivers");

    // Enrich each driver row with its user record (if present) under the 'user' key.
    final List<Map<String, dynamic>> out = [];
    for (final row in result) {
      final drv = row.toColumnMap();
      final userId = drv['user_id'];
      Map<String, dynamic>? userMap;
      if (userId != null) {
        try {
          final ures = await db.query('SELECT * FROM users WHERE user_id = @id', substitutionValues: {'id': userId});
          if (ures.isNotEmpty) userMap = ures.first.toColumnMap();
        } catch (_) {
          // ignore per-driver user lookup errors; leave userMap null
        }
      }
      // Merge driver fields and attach user under 'user'
      final merged = Map<String, dynamic>.from(drv);
      merged['user'] = userMap;
      out.add(merged);
    }

    return Response.ok(_jsonEncodeSafe(out));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

// Shuttle Handlers
Future<Response> _createShuttleHandler(Request request) async {
    final body = await request.readAsString();
  final params = jsonDecode(body);

  try {
    final result = await db.query(
      'INSERT INTO shuttles (make, model, year, capacity, license_plate, status_id, type_id) VALUES (@make, @model, @year, @capacity, @plate, @status, @type) RETURNING *',
      substitutionValues: {
        'make': params['make'],
        'model': params['model'],
        'year': params['year'],
        'capacity': params['capacity'],
        'plate': params['licensePlate'],
        'status': params['statusId'],
        'type': params['typeId'],
      },
    );
    return Response.ok(_jsonEncodeSafe({
      'message': 'Shuttle created successfully',
      'shuttle': result.first.toColumnMap(),
    }));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _updateShuttleHandler(Request request, String id) async {
    final body = await request.readAsString();
  final params = jsonDecode(body);

  try {
    final result = await db.query(
      'UPDATE shuttles SET make = @make, model = @model, year = @year, capacity = @capacity, license_plate = @plate, status_id = @status, type_id = @type WHERE shuttle_id = @id RETURNING *',
      substitutionValues: {
        'id': int.parse(id),
        'make': params['make'],
        'model': params['model'],
        'year': params['year'],
        'capacity': params['capacity'],
        'plate': params['licensePlate'],
        'status': params['statusId'],
        'type': params['typeId'],
      },
    );
    return Response.ok(_jsonEncodeSafe({
      'message': 'Shuttle updated successfully',
      'shuttle': result.first.toColumnMap(),
    }));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _updateShuttleStatusHandler(Request request, String id) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  final statusId = params['statusId'];

  if (statusId == null) {
    return Response.badRequest(body: _jsonEncodeSafe({'error': 'Missing statusId'}));
  }
  
  final shuttleId = int.tryParse(id);
  if (shuttleId == null) {
    return Response.badRequest(body: _jsonEncodeSafe({'error': 'Invalid shuttle ID'}));
  }

  try {
    final result = await db.query(
      'UPDATE shuttles SET status_id = @statusId WHERE shuttle_id = @id RETURNING shuttle_id',
      substitutionValues: {
        'id': shuttleId,
        'statusId': statusId,
      },
    );
    if (result.isEmpty) {
      return Response.notFound(_jsonEncodeSafe({'error': 'Shuttle not found'}));
    }
    
    // Join with status and type tables to return the full shuttle object
    final updatedShuttle = await db.query('''
      SELECT 
        s.*, 
        ss.status_name, 
        st.type_name 
      FROM shuttles s
      LEFT JOIN shuttle_status ss ON s.status_id = ss.status_id
      LEFT JOIN shuttle_type st ON s.type_id = st.type_id
      WHERE s.shuttle_id = @id
    ''', substitutionValues: {'id': shuttleId});


    return Response.ok(_jsonEncodeSafe({
      'message': 'Shuttle status updated successfully',
      'shuttle': updatedShuttle.first.toColumnMap(),
    }));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong', 'details': e.toString()}));
  }
}

Future<Response> _readShuttleByIdHandler(Request request, String id) async {
  try {
    final result = await db.query('''
      SELECT 
        s.*, 
        ss.status_name, 
        st.type_name 
      FROM shuttles s
      LEFT JOIN shuttle_status ss ON s.status_id = ss.status_id
      LEFT JOIN shuttle_type st ON s.type_id = st.type_id
      WHERE s.shuttle_id = @id
    ''', substitutionValues: {'id': int.parse(id)});
    if (result.isNotEmpty) {
      return Response.ok(_jsonEncodeSafe(result.first.toColumnMap()));
    } else {
      return Response.notFound(_jsonEncodeSafe({'error': 'Shuttle not found'}));
    }
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _readShuttleByPlateHandler(Request request, String plate) async {
  try {
    final result = await db.query('''
      SELECT 
        s.*, 
        ss.status_name, 
        st.type_name 
      FROM shuttles s
      LEFT JOIN shuttle_status ss ON s.status_id = ss.status_id
      LEFT JOIN shuttle_type st ON s.type_id = st.type_id
      WHERE s.license_plate = @plate
    ''', substitutionValues: {'plate': plate});
    if (result.isNotEmpty) {
      return Response.ok(_jsonEncodeSafe(result.first.toColumnMap()));
    } else {
      return Response.notFound(_jsonEncodeSafe({'error': 'Shuttle not found'}));
    }
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _deleteShuttleByIdHandler(Request request, String id) async {
  try {
    await db.query('DELETE FROM shuttles WHERE shuttle_id = @id', substitutionValues: {'id': int.parse(id)});
    return Response.ok(_jsonEncodeSafe({'message': 'Shuttle deleted successfully'}));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _deleteShuttleByPlateHandler(Request request, String plate) async {
  try {
    await db.query('DELETE FROM shuttles WHERE license_plate = @plate', substitutionValues: {'plate': plate});
    return Response.ok(_jsonEncodeSafe({'message': 'Shuttle deleted successfully'}));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _getAllShuttlesHandler(Request request) async {
  try {
    final result = await db.query('''
      SELECT 
        s.*, 
        ss.status_name, 
        st.type_name 
      FROM shuttles s
      LEFT JOIN shuttle_status ss ON s.status_id = ss.status_id
      LEFT JOIN shuttle_type st ON s.type_id = st.type_id
    ''');
    return Response.ok(_jsonEncodeSafe(result.map((row) => row.toColumnMap()).toList()));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _getShuttleStatusesHandler(Request request) async {
  try {
    final result = await db.query('SELECT * FROM shuttle_status ORDER BY status_id');
    return Response.ok(_jsonEncodeSafe(result.map((r) => r.toColumnMap()).toList()));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _getShuttleTypesHandler(Request request) async {
  try {
    final result = await db.query('SELECT * FROM shuttle_type ORDER BY type_id');
    return Response.ok(_jsonEncodeSafe(result.map((r) => r.toColumnMap()).toList()));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

// Driver Assignment Handlers
Future<Response> _createDriverAssignmentHandler(Request request) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  try {
    final result = await db.query('INSERT INTO driver_assignments (driver_id, shuttle_id, schedule_id, assignment_date) VALUES (@driverId, @shuttleId, @scheduleId, @date) RETURNING *',
    substitutionValues: {
      'driverId': params['driverId'],
      'shuttleId': params['shuttleId'],
      'scheduleId': params['scheduleId'],
      'date': params['assignmentDate']
    });
    return Response.ok(_jsonEncodeSafe({
      'message': 'Assignment created successfully',
      'assignment': result.first.toColumnMap(),
    }));
  } catch (e, st) {
    // Log details for easier debugging during development
    stderr.writeln('[Assignment] Failed to create assignment: $e\n$st');
    // If this is a Postgres exception expose some helpful details (non-sensitive)
    try {
      return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Failed to create assignment', 'details': e.toString()}));
    } catch (_) {
      return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Failed to create assignment'}));
    }
  }
}

// Read a single driver assignment by its assignment_id
Future<Response> _readDriverAssignmentByIdHandler(Request request, String id) async {
  try {
    final result = await db.query('SELECT * FROM driver_assignments WHERE assignment_id = @id', substitutionValues: {'id': int.parse(id)});
    if (result.isNotEmpty) {
      return Response.ok(_jsonEncodeSafe(result.first.toColumnMap()));
    } else {
      return Response.notFound(_jsonEncodeSafe({'error': 'Assignment not found'}));
    }
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

// Read assignments for a given driver id
Future<Response> _readAssignmentsByDriverIdHandler(Request request, String driverId) async {
  try {
    final result = await db.query('SELECT * FROM driver_assignments WHERE driver_id = @driverId ORDER BY assignment_date DESC', substitutionValues: {'driverId': int.parse(driverId)});
    return Response.ok(_jsonEncodeSafe(result.map((row) => row.toColumnMap()).toList()));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

// Get all driver assignments
Future<Response> _getAllDriverAssignmentsHandler(Request request) async {
  try {
    final result = await db.query('SELECT * FROM driver_assignments ORDER BY assignment_date DESC');
    return Response.ok(_jsonEncodeSafe(result.map((row) => row.toColumnMap()).toList()));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

// Update an existing assignment by id
Future<Response> _updateDriverAssignmentHandler(Request request, String id) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  try {
    final result = await db.query('UPDATE driver_assignments SET driver_id = @driverId, shuttle_id = @shuttleId, schedule_id = @scheduleId, assignment_date = @date WHERE assignment_id = @id RETURNING *',
      substitutionValues: {
        'id': int.parse(id),
        'driverId': params['driverId'],
        'shuttleId': params['shuttleId'],
        'scheduleId': params['scheduleId'],
        'date': params['assignmentDate']
      }
    );
    if (result.isNotEmpty) {
      return Response.ok(_jsonEncodeSafe({'message': 'Assignment updated successfully', 'assignment': result.first.toColumnMap()}));
    } else {
      return Response.notFound(_jsonEncodeSafe({'error': 'Assignment not found'}));
    }
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong', 'details': e.toString()}));
  }
}

// Delete an assignment by id
Future<Response> _deleteDriverAssignmentByIdHandler(Request request, String id) async {
  try {
    await db.query('DELETE FROM driver_assignments WHERE assignment_id = @id', substitutionValues: {'id': int.parse(id)});
    return Response.ok(_jsonEncodeSafe({'message': 'Assignment deleted successfully'}));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

// Complaint Handlers
Future<Response> _createComplaintHandler(Request request) async {
    final body = await request.readAsString();
  final params = jsonDecode(body);
  try {
    final result = await db.query('INSERT INTO complaints (user_id, title, description, status_id) VALUES (@userId, @title, @description, @statusId) RETURNING *',
    substitutionValues: {
      'userId': params['userId'],
      'title': params['title'],
      'description': params['description'],
      'statusId': params['statusId']
    });
    return Response.ok(_jsonEncodeSafe({
      'message': 'Complaint created successfully',
      'complaint': result.first.toColumnMap(),
    }));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _getAllComplaintsHandler(Request request) async {
  try {
    final result = await db.query('SELECT * FROM complaints');
    return Response.ok(_jsonEncodeSafe(result.map((row) => row.toColumnMap()).toList()));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _getComplaintByIdHandler(Request request, String id) async {
  try {
    final result = await db.query('SELECT * FROM complaints WHERE complaint_id = @id', substitutionValues: {'id': int.parse(id)});
    if (result.isNotEmpty) {
      return Response.ok(_jsonEncodeSafe(result.first.toColumnMap()));
    } else {
      return Response.notFound(_jsonEncodeSafe({'error': 'Complaint not found'}));
    }
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _updateComplaintHandler(Request request, String id) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  try {
    final result = await db.query('UPDATE complaints SET status_id = @statusId WHERE complaint_id = @id RETURNING *',
    substitutionValues: {
      'id': int.parse(id),
      'statusId': params['statusId']
    });
    return Response.ok(_jsonEncodeSafe({
      'message': 'Complaint updated successfully',
      'complaint': result.first.toColumnMap(),
    }));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

// Route Handlers
Future<Response> _createRouteHandler(Request request) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  try {
    final result = await db.query('INSERT INTO routes (name, description) VALUES (@name, @description) RETURNING *',
    substitutionValues: {
      'name': params['name'],
      'description': params['description']
    });
    return Response.ok(_jsonEncodeSafe({
      'message': 'Route created successfully',
      'route': result.first.toColumnMap(),
    }));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _getAllRoutesHandler(Request request) async {
  try {
    final result = await db.query('SELECT * FROM routes');
    return Response.ok(_jsonEncodeSafe(result.map((row) => row.toColumnMap()).toList()));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _getRouteByIdHandler(Request request, String id) async {
  try {
    final result = await db.query('SELECT * FROM routes WHERE route_id = @id', substitutionValues: {'id': int.parse(id)});
    if (result.isNotEmpty) {
      return Response.ok(_jsonEncodeSafe(result.first.toColumnMap()));
    } else {
      return Response.notFound(_jsonEncodeSafe({'error': 'Route not found'}));
    }
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _updateRouteHandler(Request request, String id) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  try {
    final result = await db.query('UPDATE routes SET name = @name, description = @description WHERE route_id = @id RETURNING *',
    substitutionValues: {
      'id': int.parse(id),
      'name': params['name'],
      'description': params['description']
    });
    return Response.ok(_jsonEncodeSafe({
      'message': 'Route updated successfully',
      'route': result.first.toColumnMap(),
    }));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _deleteRouteHandler(Request request, String id) async {
  try {
    await db.query('DELETE FROM routes WHERE route_id = @id', substitutionValues: {'id': int.parse(id)});
    return Response.ok(_jsonEncodeSafe({'message': 'Route deleted successfully'}));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _addStopToRouteHandler(Request request, String id) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  try {
    final routeId = int.parse(id);

    // Ensure route exists before attempting insert so we can return a clear 404
    final routeCheck = await db.query('SELECT route_id FROM routes WHERE route_id = @id', substitutionValues: {'id': routeId});
    if (routeCheck.isEmpty) {
      return Response.notFound(_jsonEncodeSafe({'error': 'Route not found'}));
    }

    final rawName = params['name'];
    final rawLat = params['latitude'] ?? params['lat'];
    final rawLng = params['longitude'] ?? params['lng'];

    final name = rawName?.toString();
    final latitude = (rawLat is num) ? rawLat.toDouble() : (rawLat != null ? double.tryParse(rawLat.toString()) : null);
    final longitude = (rawLng is num) ? rawLng.toDouble() : (rawLng != null ? double.tryParse(rawLng.toString()) : null);

    if (name == null || name.isEmpty) {
      return Response.badRequest(body: _jsonEncodeSafe({'error': 'Missing stop name'}));
    }
    if (latitude == null || longitude == null) {
      return Response.badRequest(body: _jsonEncodeSafe({'error': 'Missing latitude or longitude'}));
    }

    // Determine order: use provided 'order' if present, otherwise compute next sequence for the route
    int? providedOrder;
    if (params.containsKey('order')) {
      final rawOrder = params['order'];
      if (rawOrder is int) providedOrder = rawOrder;
      else if (rawOrder is num) providedOrder = rawOrder.toInt();
      else if (rawOrder is String) providedOrder = int.tryParse(rawOrder);
    }

    int order;
    if (providedOrder != null) {
      order = providedOrder;
    } else {
      final maxRes = await db.query('SELECT MAX("order") AS max_order FROM stops WHERE route_id = @routeId', substitutionValues: {'routeId': routeId});
      dynamic maxRaw;
      if (maxRes.isNotEmpty) maxRaw = maxRes.first.toColumnMap()['max_order'];
      int? maxVal;
      if (maxRaw is num) maxVal = maxRaw.toInt();
      else if (maxRaw is String) maxVal = int.tryParse(maxRaw);
      else maxVal = null;
      order = (maxVal ?? 0) + 1;
    }

    final result = await db.query(
      'INSERT INTO stops (route_id, name, latitude, longitude, "order") VALUES (@routeId, @name, @lat, @lng, @order) RETURNING *',
      substitutionValues: {
        'routeId': routeId,
        'name': name,
        'lat': latitude,
        'lng': longitude,
        'order': order,
      },
    );

    return Response.ok(_jsonEncodeSafe({
      'message': 'Stop added successfully',
      'stop': result.first.toColumnMap(),
    }));
  } on pg.PostgreSQLException catch (e, st) {
    stderr.writeln('[_addStopToRouteHandler] PostgreSQLException: ${e.code} ${e.message}\n$st');
    // Foreign key violation (route not found) -> 404
    if (e.code == '23503') {
      return Response.notFound(_jsonEncodeSafe({'error': 'Route not found'}));
    }
    // Not-null violation -> bad request
    if (e.code == '23502') {
      return Response.badRequest(body: _jsonEncodeSafe({'error': 'Missing required field', 'details': e.message}));
    }
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Database error', 'code': e.code, 'message': e.message}));
  } catch (e, st) {
    stderr.writeln('[_addStopToRouteHandler] Unexpected error: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong', 'message': e.toString()}));
  }
}

// Handler to create a stop (not tied to a specific route)
Future<Response> _createStopHandler(Request request) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  try {
    final name = params['name']?.toString();
    final latitude = (params['latitude'] is num)
        ? params['latitude'].toDouble()
        : (params['latitude'] != null ? double.tryParse(params['latitude'].toString()) : null);
    final longitude = (params['longitude'] is num)
        ? params['longitude'].toDouble()
        : (params['longitude'] != null ? double.tryParse(params['longitude'].toString()) : null);
    final routeId = params['routeId'] != null ? int.tryParse(params['routeId'].toString()) : null;
    final order = params['order'] != null ? int.tryParse(params['order'].toString()) : null;

    if (name == null || name.isEmpty) {
      return Response.badRequest(body: _jsonEncodeSafe({'error': 'Missing stop name'}));
    }
    if (latitude == null || longitude == null) {
      return Response.badRequest(body: _jsonEncodeSafe({'error': 'Missing latitude or longitude'}));
    }
    if (routeId == null) {
      return Response.badRequest(body: _jsonEncodeSafe({'error': 'Missing routeId'}));
    }

    final result = await db.query(
      'INSERT INTO stops (route_id, name, latitude, longitude, "order") VALUES (@routeId, @name, @lat, @lng, @order) RETURNING *',
      substitutionValues: {
        'routeId': routeId,
        'name': name,
        'lat': latitude,
        'lng': longitude,
        'order': order ?? 1,
      },
    );
    return Response.ok(_jsonEncodeSafe({
      'message': 'Stop created successfully',
      'stop': result.first.toColumnMap(),
    }));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong', 'details': e.toString()}));
  }
}

// Handler to get all stops for a specific route
Future<Response> _getRouteStopsByRouteIdHandler(Request request, String routeId) async {
  try {
    final rid = int.tryParse(routeId);
    if (rid == null) {
      return Response.badRequest(body: _jsonEncodeSafe({'error': 'Invalid route id'}));
    }
    final res = await db.query('SELECT * FROM stops WHERE route_id = @routeId ORDER BY "order"', substitutionValues: {'routeId': rid});
    return Response.ok(_jsonEncodeSafe(res.map((r) => r.toColumnMap()).toList()));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

// Schedules
Future<Response> _createScheduleHandler(Request request) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  try {
    final result = await db.query('INSERT INTO schedules (route_id, departure_time, arrival_time, day_of_week) VALUES (@routeId, @departure, @arrival, @day) RETURNING schedule_id, route_id, departure_time::text AS departure_time, arrival_time::text AS arrival_time, day_of_week',
    substitutionValues: {
      'routeId': params['routeId'],
      'departure': params['departureTime'],
      'arrival': params['arrivalTime'],
      'day': params['dayOfWeek']
    });
    return Response.ok(_jsonEncodeSafe({
      'message': 'Schedule created successfully',
      'schedule': result.first.toColumnMap(),
    }));
  } catch (e, st) {
    stderr.writeln('[_createScheduleHandler] Error creating schedule: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong', 'details': e.toString()}));
  }
}

Future<Response> _getScheduleByIdHandler(Request request, String id) async {
  try {
    final result = await db.query('SELECT schedule_id, route_id, departure_time::text AS departure_time, arrival_time::text AS arrival_time, day_of_week FROM schedules WHERE schedule_id = @id', substitutionValues: {'id': int.parse(id)});
    if (result.isNotEmpty) {
      return Response.ok(_jsonEncodeSafe(result.first.toColumnMap()));
    } else {
      return Response.notFound(_jsonEncodeSafe({'error': 'Schedule not found'}));
    }
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _getScheduleByDriverIdHandler(Request request, String driverId) async {
  try {
    final result = await db.query('SELECT s.schedule_id, s.route_id, s.departure_time::text AS departure_time, s.arrival_time::text AS arrival_time, s.day_of_week FROM schedules s JOIN driver_assignments da ON s.schedule_id = da.schedule_id WHERE da.driver_id = @driverId',
    substitutionValues: {'driverId': int.parse(driverId)});
    return Response.ok(_jsonEncodeSafe(result.map((row) => row.toColumnMap()).toList()));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _getAllSchedulesHandler(Request request) async {
  try {
    final result = await db.query('SELECT schedule_id, route_id, departure_time::text AS departure_time, arrival_time::text AS arrival_time, day_of_week FROM schedules');
    return Response.ok(_jsonEncodeSafe(result.map((row) => row.toColumnMap()).toList()));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _updateScheduleHandler(Request request, String id) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  try {
    final result = await db.query('UPDATE schedules SET route_id = @routeId, departure_time = @departure, arrival_time = @arrival, day_of_week = @day WHERE schedule_id = @id RETURNING *',
    substitutionValues: {
      'id': int.parse(id),
      'routeId': params['routeId'],
      'departure': params['departureTime'],
      'arrival': params['arrivalTime'],
      'day': params['dayOfWeek']
    });
    return Response.ok(_jsonEncodeSafe({
      'message': 'Schedule updated successfully',
      'schedule': result.first.toColumnMap(),
    }));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}

Future<Response> _deleteScheduleHandler(Request request, String id) async {
  try {
    await db.query('DELETE FROM schedules WHERE schedule_id = @id', substitutionValues: {'id': int.parse(id)});
    return Response.ok(_jsonEncodeSafe({'message': 'Schedule deleted successfully'}));
  } catch (e) {
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Something went wrong'}));
  }
}


// Notification Handlers
Future<Response> _createNotificationHandler(Request request) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  final dynamic userId = params['userId']; // nullable
  final title = params['title'];
  final message = params['message'];
  // keep sendNow param for backward compatibility but ignore server-side pushing
  final bool _ = params['sendNow'] == true || params['send'] == true;

  if (title == null || message == null) {
    return Response.badRequest(body: _jsonEncodeSafe({'error': 'Missing title or message'}));
  }

  try {
    final result = await db.query(
      'INSERT INTO notifications (user_id, title, message) VALUES (@userId, @title, @message) RETURNING *',
      substitutionValues: {
        'userId': userId,
        'title': title,
        'message': message,
      },
    );

    final notif = result.first.toColumnMap();

    // NOTE: We intentionally do NOT perform server-side FCM sends here.
    // Notifications are persisted in Postgres and clients should fetch them
    // by polling (e.g. GET /notifications/getAll?userId=...) or using a
    // push gateway outside this service. Keeping the device table and
    // sendTest endpoint available for future opt-in integrations.

    return Response.ok(_jsonEncodeSafe({'message': 'Notification created successfully', 'notification': notif}));
  } catch (e, st) {
    stderr.writeln('[_createNotificationHandler] Error: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Failed to create notification', 'details': e.toString()}));
  }
}

// Batch-create notifications. Supports:
// - recipients: list of user IDs -> inserts one notification per user
// - audience: string (e.g. ALL_DRIVERS) -> inserts a single broadcast row (user_id = NULL)
Future<Response> _batchCreateNotificationsHandler(Request request) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  final recipients = params['recipients'];
  final audience = params['audience'];
  final title = params['title'];
  final message = params['message'];

  if ((recipients == null || (recipients is List && recipients.isEmpty)) && (audience == null)) {
    return Response.badRequest(body: _jsonEncodeSafe({'error': 'Missing recipients or audience'}));
  }
  if (title == null || message == null) {
    return Response.badRequest(body: _jsonEncodeSafe({'error': 'Missing title or message'}));
  }

  try {
    if (recipients != null && recipients is List) {
      // Insert one notification per recipient
      final inserted = [];
      for (final r in recipients) {
        final uid = int.tryParse(r.toString()) ?? r;
        final res = await db.query(
          'INSERT INTO notifications (user_id, title, message) VALUES (@userId, @title, @message) RETURNING *',
          substitutionValues: {'userId': uid, 'title': title, 'message': message},
        );
        inserted.add(res.first.toColumnMap());
      }
      return Response.ok(_jsonEncodeSafe({'message': 'Notifications created', 'notifications': inserted}));
    }

    // If audience provided, insert single broadcast row (user_id = NULL)
    await db.query(
      'INSERT INTO notifications (user_id, title, message) VALUES (NULL, @title, @message) RETURNING *',
      substitutionValues: {'title': title, 'message': message},
    );
    return Response.ok(_jsonEncodeSafe({'message': 'Broadcast notification created'}));
  } catch (e, st) {
    stderr.writeln('[_batchCreateNotificationsHandler] Error: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Failed to create notifications', 'details': e.toString()}));
  }
}

Future<Response> _updateNotificationHandler(Request request) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  final id = params['notificationId'] ?? params['id'];
  if (id == null) return Response.badRequest(body: _jsonEncodeSafe({'error': 'Missing notification id'}));

  final title = params['title'];
  final message = params['message'];
  final isRead = params['isRead'];

  try {
    // Build update dynamically based on provided fields
    final updates = <String>[];
    final subs = <String, dynamic>{'id': int.tryParse(id.toString()) ?? id};
    if (title != null) {
      updates.add('title = @title');
      subs['title'] = title;
    }
    if (message != null) {
      updates.add('message = @message');
      subs['message'] = message;
    }
    if (isRead != null) {
      updates.add('is_read = @isRead');
      subs['isRead'] = isRead == true;
    }

    if (updates.isEmpty) {
      return Response.badRequest(body: _jsonEncodeSafe({'error': 'No fields to update'}));
    }

    final sql = 'UPDATE notifications SET ${updates.join(', ')} WHERE notification_id = @id RETURNING *';
    final res = await db.query(sql, substitutionValues: subs);
    if (res.isEmpty) return Response.notFound(_jsonEncodeSafe({'error': 'Notification not found'}));
    final updated = res.first.toColumnMap();
    return Response.ok(_jsonEncodeSafe({'message': 'Notification updated successfully', 'notification': updated}));
  } catch (e, st) {
    stderr.writeln('[_updateNotificationHandler] Error: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Failed to update notification', 'details': e.toString()}));
  }
}

Future<Response> _readNotificationByIdHandler(Request request, String id) async {
  try {
    final nid = int.tryParse(id);
    if (nid == null) return Response.badRequest(body: _jsonEncodeSafe({'error': 'Invalid id format'}));
    final res = await db.query('SELECT * FROM notifications WHERE notification_id = @id', substitutionValues: {'id': nid});
    if (res.isEmpty) return Response.notFound(_jsonEncodeSafe({'error': 'Notification not found'}));
    return Response.ok(_jsonEncodeSafe(res.first.toColumnMap()));
  } catch (e, st) {
    stderr.writeln('[_readNotificationByIdHandler] Error: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Failed to read notification', 'details': e.toString()}));
  }
}

Future<Response> _deleteNotificationByIdHandler(Request request, String id) async {
  try {
    final nid = int.tryParse(id);
    if (nid == null) return Response.badRequest(body: _jsonEncodeSafe({'error': 'Invalid id format'}));
    await db.query('DELETE FROM notifications WHERE notification_id = @id', substitutionValues: {'id': nid});
    return Response.ok(_jsonEncodeSafe({'message': 'Notification deleted'}));
  } catch (e, st) {
    stderr.writeln('[_deleteNotificationByIdHandler] Error: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Failed to delete notification', 'details': e.toString()}));
  }
}

Future<Response> _getAllNotificationsHandler(Request request) async {
   try {
     final qp = request.url.queryParameters;
     final userIdParam = qp['userId'] ?? qp['user_id'];

    String sql = 'SELECT * FROM notifications';
    final subs = <String, dynamic>{};
    final where = <String>[];
    if (userIdParam != null) {
      // include broadcasts (user_id IS NULL) along with user-specific notifications
      where.add('(user_id = @userId OR user_id IS NULL)');
      subs['userId'] = int.tryParse(userIdParam) ?? userIdParam;
    }
     if (qp['unread'] != null) {
       final v = qp['unread'];
       if (v == '1' || v?.toLowerCase() == 'true') {
         where.add('is_read = FALSE');
       } else if (v == '0' || v?.toLowerCase() == 'false') {
         where.add('is_read = TRUE');
       }
     }
     if (where.isNotEmpty) sql += ' WHERE ${where.join(' AND ')}';
     sql += ' ORDER BY created_at DESC';

     final res = await db.query(sql, substitutionValues: subs);
     final list = res.map((r) => r.toColumnMap()).toList();
     return Response.ok(_jsonEncodeSafe(list));
   } catch (e, st) {
     stderr.writeln('[_getAllNotificationsHandler] Error: $e\n$st');
     return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Failed to fetch notifications', 'details': e.toString()}));
   }
}

// Device token handlers
Future<Response> _registerDeviceHandler(Request request) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  final deviceToken = (params['deviceToken'] ?? params['token'])?.toString();
  if (deviceToken == null || deviceToken.isEmpty) {
    return Response.badRequest(body: _jsonEncodeSafe({'error': 'Missing deviceToken'}));
  }
  final userIdInput = params['userId'] ?? params['user_id'];
  final platform = params['platform']?.toString();
  final userId = userIdInput == null ? null : (int.tryParse(userIdInput.toString()) ?? userIdInput);

  try {
    final res = await db.query(
      'INSERT INTO user_devices (user_id, device_token, platform) VALUES (@userId, @token, @platform) ON CONFLICT (device_token) DO UPDATE SET user_id = EXCLUDED.user_id, platform = EXCLUDED.platform RETURNING *',
      substitutionValues: {'userId': userId, 'token': deviceToken, 'platform': platform},
    );
    return Response.ok(_jsonEncodeSafe({'message': 'Device registered', 'device': res.first.toColumnMap()}));
  } catch (e, st) {
    stderr.writeln('[_registerDeviceHandler] Error: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Failed to register device', 'details': e.toString()}));
  }
}

Future<Response> _deleteDeviceByTokenHandler(Request request, String token) async {
  try {
    await db.query('DELETE FROM user_devices WHERE device_token = @token', substitutionValues: {'token': token});
    return Response.ok(_jsonEncodeSafe({'message': 'Device deleted'}));
  } catch (e, st) {
    stderr.writeln('[_deleteDeviceByTokenHandler] Error: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Failed to delete device', 'details': e.toString()}));
  }
}

Future<Response> _getDevicesByUserHandler(Request request, String userId) async {
  try {
    final uid = int.tryParse(userId) ?? userId;
    final res = await db.query('SELECT * FROM user_devices WHERE user_id = @userId ORDER BY created_at DESC', substitutionValues: {'userId': uid});
    return Response.ok(_jsonEncodeSafe(res.map((r) => r.toColumnMap()).toList()));
  } catch (e, st) {
    stderr.writeln('[_getDevicesByUserHandler] Error: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Failed to fetch devices', 'details': e.toString()}));
  }
}

Future<Response> _getAllDevicesHandler(Request request) async {
  try {
    final res = await db.query('SELECT * FROM user_devices ORDER BY created_at DESC');
    return Response.ok(_jsonEncodeSafe(res.map((r) => r.toColumnMap()).toList()));
  } catch (e, st) {
    stderr.writeln('[_getAllDevicesHandler] Error: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Failed to fetch devices', 'details': e.toString()}));
  }
}

Future<Response> _sendTestNotificationHandler(Request request) async {
  // Server-side FCM sending has been disabled in favor of Postgres-only notifications.
  // Keep this endpoint for compatibility but inform callers that direct sends are not performed.
  return Response(410, body: _jsonEncodeSafe({'error': 'Server-side FCM sending is disabled. Notifications are stored in the database; clients should poll /notifications/getAll or use a separate push gateway if desired.'}));
}

// Feedback Handlers (CRUD against feedback table)
Future<Response> _createFeedbackHandler(Request request) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  final userId = params['userId'];
  final rating = params['rating'];
  final comment = params['comment'];

  if (userId == null || rating == null) {
    return Response.badRequest(body: _jsonEncodeSafe({'error': 'Missing userId or rating'}));
  }

  try {
    final res = await db.query(
      'INSERT INTO feedback (user_id, rating, comment) VALUES (@userId, @rating, @comment) RETURNING *',
      substitutionValues: {'userId': userId, 'rating': rating, 'comment': comment},
    );
    return Response.ok(_jsonEncodeSafe({'message': 'Feedback created successfully', 'feedback': res.first.toColumnMap()}));
  } catch (e, st) {
    stderr.writeln('[_createFeedbackHandler] Error: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Failed to create feedback', 'details': e.toString()}));
  }
}

Future<Response> _updateFeedbackHandler(Request request) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  final id = params['feedbackId'] ?? params['id'];
  if (id == null) return Response.badRequest(body: _jsonEncodeSafe({'error': 'Missing feedback id'}));

  final rating = params['rating'];
  final comment = params['comment'];

  try {
    final updates = <String>[];
    final subs = <String, dynamic>{'id': int.tryParse(id.toString()) ?? id};
    if (rating != null) {
      updates.add('rating = @rating');
      subs['rating'] = rating;
    }
    if (comment != null) {
      updates.add('comment = @comment');
      subs['comment'] = comment;
    }
    if (updates.isEmpty) return Response.badRequest(body: _jsonEncodeSafe({'error': 'No fields to update'}));

    final sql = 'UPDATE feedback SET ${updates.join(', ')} WHERE feedback_id = @id RETURNING *';
    final res = await db.query(sql, substitutionValues: subs);
    if (res.isEmpty) return Response.notFound(_jsonEncodeSafe({'error': 'Feedback not found'}));
    return Response.ok(_jsonEncodeSafe({'message': 'Feedback updated successfully', 'feedback': res.first.toColumnMap()}));
  } catch (e, st) {
    stderr.writeln('[_updateFeedbackHandler] Error: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Failed to update feedback', 'details': e.toString()}));
  }
}

Future<Response> _readFeedbackByIdHandler(Request request, String id) async {
  try {
    final fid = int.tryParse(id);
    if (fid == null) return Response.badRequest(body: _jsonEncodeSafe({'error': 'Invalid id format'}));
    final res = await db.query('SELECT * FROM feedback WHERE feedback_id = @id', substitutionValues: {'id': fid});
    if (res.isEmpty) return Response.notFound(_jsonEncodeSafe({'error': 'Feedback not found'}));
    return Response.ok(_jsonEncodeSafe(res.first.toColumnMap()));
  } catch (e, st) {
    stderr.writeln('[_readFeedbackByIdHandler] Error: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Failed to read feedback', 'details': e.toString()}));
  }
}

Future<Response> _deleteFeedbackByIdHandler(Request request, String id) async {
  try {
    final fid = int.tryParse(id);
    if (fid == null) return Response.badRequest(body: _jsonEncodeSafe({'error': 'Invalid id format'}));
    await db.query('DELETE FROM feedback WHERE feedback_id = @id', substitutionValues: {'id': fid});
    return Response.ok(_jsonEncodeSafe({'message': 'Feedback deleted'}));
  } catch (e, st) {
    stderr.writeln('[_deleteFeedbackByIdHandler] Error: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Failed to delete feedback', 'details': e.toString()}));
  }
}

Future<Response> _getAllFeedbacksHandler(Request request) async {
  try {
    final res = await db.query('SELECT * FROM feedback ORDER BY created_at DESC');
    return Response.ok(_jsonEncodeSafe(res.map((r) => r.toColumnMap()).toList()));
  } catch (e, st) {
    stderr.writeln('[_getAllFeedbacksHandler] Error: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Failed to fetch feedbacks', 'details': e.toString()}));
  }
}

// Maintenance Handlers
Future<Response> _createMaintenanceReportHandler(Request request) async {
  final body = await request.readAsString();
  final params = jsonDecode(body);
  final shuttleId = params['shuttleId'];
  final reportDate = params['reportDate'];
  final description = params['description'];
  final resolved = params['resolved'] ?? false;

  if (shuttleId == null || reportDate == null || description == null) {
    return Response.badRequest(body: _jsonEncodeSafe({'error': 'Missing shuttleId, reportDate or description'}));
  }

  try {
    final res = await db.query(
      'INSERT INTO maintenance (shuttle_id, report_date, description, resolved) VALUES (@shuttleId, @date, @description, @resolved) RETURNING *',
      substitutionValues: {'shuttleId': shuttleId, 'date': reportDate, 'description': description, 'resolved': resolved},
    );
    return Response.ok(_jsonEncodeSafe({'message': 'Maintenance report created successfully', 'report': res.first.toColumnMap()}));
  } catch (e, st) {
    stderr.writeln('[_createMaintenanceReportHandler] Error: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Failed to create maintenance report', 'details': e.toString()}));
  }
}

// Location Handlers
Future<Response> _updateLocationHandler(Request request) async {
  // Accept a JSON body containing location fields and broadcast to connected websocket clients.
  try {
    final body = await request.readAsString();
    if (body.trim().isEmpty) return Response.badRequest(body: _jsonEncodeSafe({'error': 'Empty body'}));
    final data = jsonDecode(body);
    if (data is! Map<String, dynamic>) return Response.badRequest(body: _jsonEncodeSafe({'error': 'Invalid payload'}));

    // Normalize keys expected by clients: driverId, shuttleId, latitude, longitude, timestamp, status
    final msg = <String, dynamic>{
      'driverId': data['driverId']?.toString() ?? data['driver_id']?.toString(),
      'shuttleId': data['shuttleId']?.toString() ?? data['shuttle_id']?.toString(),
      'latitude': data['latitude'],
      'longitude': data['longitude'],
      'timestamp': data['timestamp'] ?? data['ts'] ?? DateTime.now().toIso8601String(),
      'status': data['status'],
    };

    // Broadcast to connected WS clients (if any).
    try {
      _broadcastLocationMessage(msg);
    } catch (e, st) {
      stderr.writeln('[broadcast] failed: $e\n$st');
    }

    return Response.ok(_jsonEncodeSafe({'ok': true, 'broadcasted_to': _wsClients.length, 'message': msg}));
  } catch (e, st) {
    stderr.writeln('[updateLocation] Unexpected error: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Failed to process location update', 'details': e.toString()}));
  }
}

Response _getRecentLocationsHandler(Request request) {
  // Not implemented: return empty list to avoid breaking callers.
  return Response.ok(_jsonEncodeSafe([]));
}

// Dev helper: create a driver row for an existing user (development-only)
Future<Response> _seedDriverFromUserHandler(Request request, String userIdStr) async {
  final uid = int.tryParse(userIdStr);
  if (uid == null) return Response.badRequest(body: _jsonEncodeSafe({'error': 'Invalid user id'}));
  try {
    // Verify user exists
    final ures = await db.query('SELECT * FROM users WHERE user_id = @id', substitutionValues: {'id': uid});
    if (ures.isEmpty) return Response.notFound(_jsonEncodeSafe({'error': 'User not found'}));

    // If driver already exists for user, return it
    final dres = await db.query('SELECT * FROM drivers WHERE user_id = @id', substitutionValues: {'id': uid});
    if (dres.isNotEmpty) return Response.ok(_jsonEncodeSafe(dres.first.toColumnMap()));

    // Create a dev license and insert driver
    final license = 'DEV-LIC-${uid}-${DateTime.now().millisecondsSinceEpoch}';
    final ires = await db.query(
      'INSERT INTO drivers (user_id, license_number, phone_number) VALUES (@userId, @license, @phone) RETURNING *',
      substitutionValues: {'userId': uid, 'license': license, 'phone': null},
    );
    final drv = ires.first.toColumnMap();
    // Attach the user row for convenience
    drv['user'] = ures.first.toColumnMap();
    return Response.ok(_jsonEncodeSafe(drv));
  } catch (e, st) {
    stderr.writeln('[DevSeed] Failed to seed driver from user $userIdStr: $e\n$st');
    return Response.internalServerError(body: _jsonEncodeSafe({'error': 'Failed to seed driver', 'details': e.toString()}));
  }
}



void main(List<String> args) async {
  await db.connect();
  final skipFb = (Platform.environment['SKIP_FIREBASE'] ?? '').toLowerCase();
  final skipFirebaseEnv = skipFb == '1' || skipFb == 'true' || skipFb == 'yes';
  final shouldSkipFirebase = skipFirebaseEnv || !db.isConnected;
  if (!shouldSkipFirebase) {
    try {
      await firebaseAdmin.init();
    } catch (e, st) {
      stderr.writeln('[main] Warning: firebase initialization failed: $e');
      stderr.writeln(st);
    }
  } else {
    stdout.writeln('[main] SKIP_FIREBASE is set or DB not connected — skipping firebase admin initialization.');
  }

  // Insert default roles and other reference data
  if (db.isConnected) {
    await db.query("INSERT INTO roles (role_name) VALUES ('STUDENT'), ('DISABLED_STUDENT'), ('ADMIN'), ('DRIVER') ON CONFLICT (role_name) DO NOTHING;");
    await db.query("INSERT INTO shuttle_status (status_name) VALUES ('AVAILABLE'), ('UNDER_MAINTENANCE'), ('OUT_OF_SERVICE') ON CONFLICT (status_name) DO NOTHING;");
    await db.query("INSERT INTO shuttle_type (type_name) VALUES ('BUS'), ('MINIBUS') ON CONFLICT (type_name) DO NOTHING;");
    await db.query("INSERT INTO complaint_status (status_name) VALUES ('OPEN'), ('RESOLVED'), ('CLOSED') ON CONFLICT (status_name) DO NOTHING;");
  } else {
    stdout.writeln('[main] DB not connected — skipping DB seeding.');
  }

  final ip = InternetAddress.anyIPv4;
  // Use the rootRouter that exposes '/', '/api/', and '/api/v1/'
  final handler = Pipeline().addMiddleware(logRequests()).addHandler(rootRouter);
  // Try to bind to PORT (default 8080); if it's in use, try up to +9 ports.
  final basePort = int.parse(Platform.environment['PORT'] ?? '8080');
  HttpServer? httpServer;
  int boundPort = basePort;
  for (int i = 0; i < 10; i++) {
    final tryPort = basePort + i;
    try {
      httpServer = await serve(handler, ip, tryPort);
      boundPort = tryPort;
      break;
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 10048) {
        // WSAEADDRINUSE on Windows
        stdout.writeln('[main] Port $tryPort is in use, trying ${tryPort + 1}...');
        continue;
      }
      rethrow;
    }
  }
  if (httpServer == null) {
    throw Exception('Failed to bind to any port in range $basePort-${basePort + 9}');
  }
  stdout.writeln('Server listening on port $boundPort');
}

