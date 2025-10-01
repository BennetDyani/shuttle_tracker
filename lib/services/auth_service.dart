import 'package:mysql1/mysql1.dart';
import '../models/user.dart';
import '../models/student.dart';
import '../models/admin.dart';
import 'database_service.dart';
import '../models/disabled_student.dart';

class AuthService {
  final DatabaseService _dbService = DatabaseService();

  // EXISTING CODE - Student Registration
  Future<User?> registerUser({
    required String name,
    required String surname,
    required String email,
    required String password,
    required String userType,
    String? disabilityType,
    bool? requiresMinibus,
    String? accessNeeds,
  }) async {
    final conn = await _dbService.connection;

    try {
      await conn.query('START TRANSACTION');

      // Insert into user table
      final userResult = await conn.query(
        'INSERT INTO User (name, surname, email, password) VALUES (?, ?, ?, ?)',
        [name, surname, email, password],
      );

      final userId = userResult.insertId;

      if (userType == 'student' || userType == 'disabled_student') {
        // Insert into student table
        final studentResult = await conn.query(
          'INSERT INTO Student (user_id) VALUES (?)',
          [userId],
        );

        final studentId = studentResult.insertId;

        if (userType == 'disabled_student' && disabilityType != null) {
          // Convert boolean to INT (1 for true, 0 for false)
          final minibusValue = requiresMinibus == true ? 1 : 0;

          // Insert into disabled student table
          await conn.query(
            'INSERT INTO DisabledStudent (student_id, disability_type, exposure_minibus, access_needs) VALUES (?, ?, ?, ?)',
            [studentId, disabilityType, minibusValue, accessNeeds ?? ''],
          );
        }
      }

      await conn.query('COMMIT');

      return User(
        userId: userId!,
        name: name,
        surname: surname,
        email: email,
        userType: userType,
      );
    } catch (e) {
      await conn.query('ROLLBACK');
      print('Registration failed: $e');
      rethrow;
    }
  }

  Future<DisabledStudent?> getDisabledStudentDetails(int userId) async {
    try {
      print('🔍 Fetching disabled student details for user ID: $userId');
      final conn = await _dbService.connection;

      final results = await conn.query(
        'SELECT ds.* FROM DisabledStudent ds '
            'JOIN Student s ON ds.student_id = s.student_id '
            'WHERE s.user_id = ?',
        [userId],
      );

      print('🔍 Query returned ${results.length} rows');

      if (results.isNotEmpty) {
        final row = results.first;
        print('🔍 Row data: $row');

        // Create DisabledStudent object
        final disabledStudent = DisabledStudent(
          disabledId: row['disabled_id'] as int,
          studentId: row['student_id'] as int,
          disabilityType: row['disability_type'] as String,
          exposureMinibus: (row['exposure_minibus'] as int) == 1,
          accessNeeds: row['access_needs'] as String? ?? '',
        );

        print('🔍 DisabledStudent created: ${disabledStudent.toMap()}');
        return disabledStudent;
      }

      print('🔍 No disabled student record found');
      return null;
    } catch (e) {
      print('❌ Error in getDisabledStudentDetails: $e');
      return null;
    }
  }

  // EXISTING CODE - Email Check
  Future<bool> checkEmailExists(String email) async {
    final conn = await _dbService.connection;

    try {
      final results = await conn.query(
        'SELECT COUNT(*) as count FROM User WHERE email = ?',
        [email],
      );

      return (results.first['count'] as int) > 0;
    } catch (e) {
      print('Email check failed: $e');
      rethrow;
    }
  }

  // UPDATED Login Method (now includes admin and driver detection)
  Future<User?> loginUser(String email, String password) async {
    final conn = await _dbService.connection;

    try {
      final results = await conn.query(
        'SELECT u.*, s.student_id, ds.disabled_id, a.admin_id, d.driver_id '
            'FROM User u '
            'LEFT JOIN Student s ON u.user_id = s.user_id '
            'LEFT JOIN DisabledStudent ds ON s.student_id = ds.student_id '
            'LEFT JOIN Admin a ON u.user_id = a.user_id '
            'LEFT JOIN Driver d ON u.user_id = d.user_id '
            'WHERE u.email = ? AND u.password = ?',
        [email, password],
      );

      if (results.isNotEmpty) {
        final row = results.first;
        String userType = 'student';

        if (row['disabled_id'] != null) {
          userType = 'disabled_student';
        } else if (row['admin_id'] != null) {
          userType = 'admin';
        } else if (row['driver_id'] != null) {
          userType = 'driver';
        }

        return User(
          userId: row['user_id'],
          name: row['name'],
          surname: row['surname'],
          email: row['email'],
          userType: userType,
        );
      }
      return null;
    } catch (e) {
      print('Login failed: $e');
      rethrow;
    }
  }

  // NEW CODE - Admin Methods
  Future<Admin?> getAdminDetails(int userId) async {
    final conn = await _dbService.connection;

    try {
      final results = await conn.query(
        'SELECT a.*, u.name, u.surname, u.email '
            'FROM Admin a '
            'JOIN User u ON a.user_id = u.user_id '
            'WHERE a.user_id = ?',
        [userId],
      );

      if (results.isNotEmpty) {
        final row = results.first;
        return Admin(
          adminId: row['admin_id'],
          userId: row['user_id'],
          name: row['name'],
          surname: row['surname'],
          email: row['email'],
        );
      }
      return null;
    } catch (e) {
      print('Failed to get admin details: $e');
      rethrow;
    }
  }

  Future<bool> registerAdmin({
    required String name,
    required String surname,
    required String email,
    required String password,
  }) async {
    final conn = await _dbService.connection;

    try {
      await conn.query('START TRANSACTION');

      // Check if email already exists
      final emailCheck = await checkEmailExists(email);
      if (emailCheck) {
        throw Exception('Email already exists');
      }

      // Insert into user table
      final userResult = await conn.query(
        'INSERT INTO User (name, surname, email, password) VALUES (?, ?, ?, ?)',
        [name, surname, email, password],
      );

      final userId = userResult.insertId;

      // Insert into admin table
      await conn.query(
        'INSERT INTO Admin (user_id) VALUES (?)',
        [userId],
      );

      await conn.query('COMMIT');
      return true;
    } catch (e) {
      await conn.query('ROLLBACK');
      print('Admin registration failed: $e');
      rethrow;
    }
  }
}