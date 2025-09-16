import 'package:mysql1/mysql1.dart';
import '../utils/database_connection.dart'; // Import your connection helper


class UserService {

  // Method to register a new user and their specific role
  static Future<void> registerUser({
    required String name,
    required String surname,
    required String email,
    required String password,
    required String userType, // Will be 'student', 'driver', or 'admin'
    String? licenseNumber, // Only required for drivers
  }) async {
    MySqlConnection? conn;
    try {
      conn = await DatabaseConnection.getConnection();

      // 1. Start a transaction to ensure both inserts succeed or fail together
      await conn.transaction((transaction) async {

        // 2. Insert into the main User table
        var userResult = await transaction.query(
            'INSERT INTO User (name, surname, email, password) VALUES (?, ?, ?, ?)',
            [name, surname, email, password] // In a real app, HASH the password first!
        );
        final int newUserId = (userResult.insertId ?? 0);

        // 3. Based on the userType, insert into the specific role table
        switch (userType) {
          case 'student':
            await transaction.query(
                'INSERT INTO Student (user_id) VALUES (?)',
                [newUserId]
            );
            break;
          case 'driver':
            if (licenseNumber == null || licenseNumber.isEmpty) {
              throw Exception('License number is required for drivers.');
            }
            await transaction.query(
                'INSERT INTO Driver (user_id, license_number) VALUES (?, ?)',
                [newUserId, licenseNumber]
            );
            break;
          case 'admin':
            await transaction.query(
                'INSERT INTO Admin (user_id) VALUES (?)',
                [newUserId]
            );
            break;
          default:
            throw Exception('Invalid user type selected.');
        }
      });

      print('User registered successfully!');
    } on MySqlException catch (e) {
      print('MySQL Error during registration: $e');
      // Handle specific errors, like duplicate email (error code 1062)
      if (e.message.contains('Duplicate entry') && e.message.contains('email')) {
        throw Exception('This email is already registered.');
      }
      rethrow; // Re-throw the exception to be handled in the UI
    } catch (e) {
      print('Error during registration: $e');
      rethrow;
    } finally {
      await conn?.close(); // Always close the connection
    }
  }
}