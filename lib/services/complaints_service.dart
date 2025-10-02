import 'database_service.dart';

class ComplaintService {
  final DatabaseService _dbService = DatabaseService();

  Future<void> submitComplaint({
    required int userId,
    required String category,
    required String message,
  }) async {
    final conn = await _dbService.connection;
    await conn.query(
      'INSERT INTO Complaint (user_id, category, message) VALUES (?, ?, ?)',
      [userId, category, message],
    );
  }

  Future<List<Map<String, dynamic>>> fetchOpenComplaints() async {
    final conn = await _dbService.connection;
    final results = await conn.query('SELECT * FROM Complaint WHERE status = "Open"');
    return results.map((row) => row.fields).toList();
  }
}