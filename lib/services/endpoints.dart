class Endpoints {
  // Auth endpoints
  static const String authLogin = 'auth/login';
  static const String authStaffLogin = 'auth/staff-login';
  static const String authSignup = 'auth/signup';

  // User endpoints
  static const String userGetAll = 'users/getAll';
  static const String userCreate = 'users/create';
  static String userReadById(int userId) => 'users/$userId';
  static String userReadByEmail(String email) => 'users/readByEmail/$email';

  // Driver endpoints
  static const String driverGetAll = 'drivers/getAll';
  static const String driverCreate = 'drivers/create';
  static String driverReadByEmail(String email) => 'drivers/readByEmail/$email';

  // Shuttle endpoints
  static const String shuttleGetAll = 'shuttles/getAll';
  static const String shuttleCreate = 'shuttles/create';

  // Route endpoints
  static String routeStopsReadByRouteId(int routeId) => 'routes/$routeId/stops';

  // Location endpoints
  static const String locationUpdate = 'location/update';
  static String locationRecent({int? limit, int? shuttleId, int? driverId}) {
    final params = <String, String>{};
    if (limit != null) params['limit'] = limit.toString();
    if (shuttleId != null) params['shuttleId'] = shuttleId.toString();
    if (driverId != null) params['driverId'] = driverId.toString();
    final query = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    return 'location/recent$query';
  }

  // Notification endpoints
  static const String notificationGetAll = 'notifications/getAll';
  static const String notificationUpdate = 'notifications/update';

  // Complaint endpoints
  static const String complaintCreate = 'complaints/create';
  static const String complaintGetAll = 'complaints/getAll';
  static const String complaintUpdate = 'complaints/update';
}
