import 'package:mysql1/mysql1.dart';

class DatabaseConnection {
  // Static method to establish a connection
  static Future<MySqlConnection> getConnection() async {
    // This is where you put your database connection details
    final settings = ConnectionSettings(
      host: 'localhost', // or your database server's IP address, e.g., '10.0.2.2' for Android emulator
      port: 3306, // default MySQL port
      user: 'root', // e.g., 'root'
      password: 'password',
      db: 'shuttle_tracking', // The database name we created
    );

    // Establish and return the connection
    return await MySqlConnection.connect(settings);
  }
}





