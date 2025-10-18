class Endpoints {
  // 1. Define the server's host and the API prefix separately.
  //    This makes it easy to switch between development and production servers.
  static const String _host = 'http://localhost:8080'; // Or your production server address
  static const String _apiPrefix = '/api';

  // 2. Combine them into a single, reliable base URL for all API calls.
  static const String baseUrl = _host + _apiPrefix;

  // --- No changes are needed for the endpoints below ---
  // They are relative paths that will be appended to the baseUrl.

  // Auth endpoints
  static const String authLogin = 'auth/login';

  // New: Staff login endpoint
  static const String authStaffLogin = 'auth/staff-login';

  // User endpoints (matching backend; relative to base, do not include '/api')
  static const String userCreate = 'users/create';
  static const String userUpdate = 'users/update';

  static String userReadById(int id) => 'users/read/$id';

  static String userReadByEmail(String email) => 'users/readByEmail/$email';

  static String userDeleteById(int id) => 'users/delete/$id';

  static String userDeleteByEmail(String email) => 'users/deleteByEmail/$email';
  static const String userGetAll = 'users/getAll';

  // Admin endpoints (example structure)
  static const String adminCreate = 'admins/create';
  static const String adminUpdate = 'admins/update';

  static String adminReadById(int id) => 'admins/read/$id';

  static String adminReadByEmail(String email) => 'admins/readByEmail/$email';

  static String adminDeleteById(int id) => 'admins/delete/$id';

  static String adminDeleteByEmail(String email) =>
      'admins/deleteByEmail/$email';
  static const String adminGetAll = 'admins/getAll';

  // Driver endpoints (example structure)
  static const String driverCreate = 'drivers/create';
  static const String driverUpdate = 'drivers/update';

  static String driverReadById(int id) => 'drivers/read/$id';

  static String driverReadByEmail(String email) => 'drivers/readByEmail/$email';

  static String driverDeleteById(int id) => 'drivers/delete/$id';

  static String driverDeleteByEmail(String email) =>
      'drivers/deleteByEmail/$email';
  static const String driverGetAll = 'drivers/getAll';

  // Shuttle endpoints (example structure)
  static const String shuttleCreate = 'shuttles/create';
  static const String shuttleUpdate = 'shuttles/update';

  static String shuttleReadById(int id) => 'shuttles/read/$id';

  static String shuttleReadByPlate(String plate) =>
      'shuttles/readByPlate/$plate';

  static String shuttleDeleteById(int id) => 'shuttles/delete/$id';

  static String shuttleDeleteByPlate(String plate) =>
      'shuttles/deleteByPlate/$plate';
  static const String shuttleGetAll = 'shuttles/getAll';

  // Notification endpoints (example structure)
  static const String notificationCreate = 'notifications/create';
  static const String notificationUpdate = 'notifications/update';

  static String notificationReadById(int id) => 'notifications/read/$id';

  static String notificationDeleteById(int id) => 'notifications/delete/$id';
  static const String notificationGetAll = 'notifications/getAll';

  // Feedback endpoints (example structure)
  static const String feedbackCreate = 'feedbacks/create';
  static const String feedbackUpdate = 'feedbacks/update';

  static String feedbackReadById(int id) => 'feedbacks/read/$id';

  static String feedbackDeleteById(int id) => 'feedbacks/delete/$id';
  static const String feedbackGetAll = 'feedbacks/getAll';

  // Complaint endpoints
  static const String complaintCreate = 'complaints/create';
  static const String complaintUpdate = 'complaints/update';
  static const String complaintGetAll = 'complaints/getAll';
  static String complaintReadById(int id) => 'complaints/read/$id';

  // Schedule endpoints
  static String scheduleReadByDriverId(int driverId) =>
      'schedules/driver/$driverId';

  // Maintenance endpoints
  static const String maintenanceReportCreate = 'maintenanceReports/create';

  // Route endpoints
  static String routeStopsReadByRouteId(int routeId) => 'routes/$routeId/stops';

  // Location endpoints
  // Matches backend controller paths:
  // POST /location/update-location
  // GET  /location/recent?limit=&shuttleId=&driverId=
  static const String locationUpdate = 'location/update-location';

  static String locationRecent({int? limit, int? shuttleId, int? driverId}) {
    final params = <String, String>{};
    if (limit != null) params['limit'] = limit.toString();
    if (shuttleId != null) params['shuttleId'] = shuttleId.toString();
    if (driverId != null) params['driverId'] = driverId.toString();
    final query = params.isNotEmpty
        ? '?${Uri(queryParameters: params).query}'
        : '';
    return 'location/recent$query';
  }

// Add more endpoints as needed for routes, complaints, etc.
}