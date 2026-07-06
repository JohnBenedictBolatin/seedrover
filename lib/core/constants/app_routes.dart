class AppRoutes {
  const AppRoutes._();

  static const login = '/login';
  static const dashboard = '/dashboard';
  static const rover = '/rover';
  static const crops = '/crops';
  static const cropDetails = '/crops/:cropId';
  static const stocks = '/stocks';
  static const stockDetails = '/stocks/:stockId';
  static const notifications = '/notifications';
  static const notificationDetails = '/notifications/:notificationId';
  static const plantingLogDetails = '/planting-logs/:logId';
  static const userDetails = '/users/:userId';
  static const profile = '/profile';

  static String cropDetailsPath(String cropId) {
    return '$crops/$cropId';
  }

  static String stockDetailsPath(String stockId) {
    return '$stocks/$stockId';
  }

  static String notificationDetailsPath(String notificationId) {
    return '$notifications/$notificationId';
  }

  static String plantingLogDetailsPath(String logId) {
    return '/planting-logs/$logId';
  }

  static String userDetailsPath(String userId) {
    return '/users/$userId';
  }
}

class AppRouteNames {
  const AppRouteNames._();

  static const login = 'login';
  static const dashboard = 'dashboard';
  static const rover = 'rover';
  static const crops = 'crops';
  static const cropDetails = 'crop-details';
  static const stocks = 'stocks';
  static const stockDetails = 'stock-details';
  static const notifications = 'notifications';
  static const notificationDetails = 'notification-details';
  static const plantingLogDetails = 'planting-log-details';
  static const userDetails = 'user-details';
  static const profile = 'profile';
}
