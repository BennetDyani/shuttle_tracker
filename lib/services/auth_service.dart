import 'package:mysql1/mysql1.dart';
import 'dart:typed_data'; // ADD THIS IMPORT

import '../models/user.dart';
import '../models/student.dart';
import 'database_service.dart';
import '../models/disabled_student.dart';

class AuthService {
  final DatabaseService _dbService = DatabaseService();

  // ADD THIS HELPER METHOD
  String? convertBlobToString(dynamic blobData) {
    if (blobData == null) return null;

    if (blobData is String) {
      return blobData;
    } else if (blobData is Uint8List) {
      return String.fromCharCodes(blobData);
    } else {
      return blobData.toString();
    }
  }

  Future<User?> registerUser({
    required String name,
    required String surname,
    required String email,
    required String password,
    required String userType,
    String? disabilityType,
    bool? exposureMinibus,
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
          final minibusValue = exposureMinibus == true ? 1 : 0;

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

  Future<User?> loginUser(String email, String password) async {
    final conn = await _dbService.connection;

    try {
      final results = await conn.query(
        'SELECT u.*, s.student_id, ds.disabled_id, ds.disability_type, ds.exposure_minibus '
            'FROM User u '
            'LEFT JOIN Student s ON u.user_id = s.user_id '
            'LEFT JOIN DisabledStudent ds ON s.student_id = ds.student_id '
            'WHERE u.email = ? AND u.password = ?',
        [email, password],
      );

      if (results.isNotEmpty) {
        final row = results.first;
        String userType = 'student';

        if (row['disabled_id'] != null) {
          userType = 'disabled_student';
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

        // USE THE HELPER METHOD TO HANDLE BLOB DATA
        final accessNeeds = convertBlobToString(row['access_needs']);

        // Create DisabledStudent object
        final disabledStudent = DisabledStudent(
          disabledId: row['disabled_id'] as int,
          studentId: row['student_id'] as int,
          disabilityType: row['disability_type'] as String,
          exposureMinibus: (row['exposure_minibus'] as int) == 1,
          accessNeeds: accessNeeds ?? '', // USE THE CONVERTED VALUE
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
}