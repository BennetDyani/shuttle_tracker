// import 'package:mysql1/mysql1.dart';
//
// class DatabaseService {
//   static final DatabaseService _instance = DatabaseService._internal();
//   factory DatabaseService() => _instance;
//   DatabaseService._internal();
//
//   MySqlConnection? _connection;
//   bool _isConnected = false;
//
//   Future<MySqlConnection> get connection async {
//     if (_connection == null) {
//       _connection = await _createConnection();
//       _isConnected = true;
//     }
//
//     // Check if connection is still valid by executing a simple query
//     try {
//       await _connection!.query('SELECT 1');
//     } catch (e) {
//       print('Connection lost, reconnecting...');
//       _connection = await _createConnection();
//       _isConnected = true;
//     }
//
//     return _connection!;
//   }
//
//   Future<MySqlConnection> _createConnection() async {
//     final settings = ConnectionSettings(
//       host: 'localhost',
//       port: 3306,
//       user: 'root',
//       password: 'Izzy@2020',
//       db: 'shuttle_tracking',
//     );
//
//     try {
//       final conn = await MySqlConnection.connect(settings);
//       print('Database connected successfully');
//       return conn;
//     } catch (e) {
//       print('Database connection failed: $e');
//       throw Exception('Failed to connect to database');
//     }
//   }
//
//   Future<void> close() async {
//     if (_connection != null) {
//       await _connection!.close();
//       _isConnected = false;
//     }
//   }
//
//   bool get isConnected => _isConnected;
// }




import 'package:mysql1/mysql1.dart';
class DatabaseService { static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance; DatabaseService._internal();
MySqlConnection? _connection; bool _isConnected = false;
Future<MySqlConnection> get connection async { if (_connection == null)
{ _connection = await _createConnection(); _isConnected = true; }
// Check if connection is still valid by executing a simple query
try {
  await _connection!.query('SELECT 1');
} catch (e) {
  print('Connection lost, reconnecting...');
  _connection = await _createConnection();
  _isConnected = true;
}

return _connection!;

}
Future<MySqlConnection> _createConnection()
async { final settings = ConnectionSettings( host: 'localhost',
                                          port: 3306,
                                          user: 'root',
                                          password: 'password',
                                          db: 'shuttle_tracking', );
try {
  final conn = await MySqlConnection.connect(settings);
  print('Database connected successfully');
  return conn;
} catch (e) {
  print('Database connection failed: $e');
  throw Exception('Failed to connect to database');
}

}
Future<void> close() async { if (_connection != null) { await _connection!.close(); _isConnected = false; } }
bool get isConnected => _isConnected; }


