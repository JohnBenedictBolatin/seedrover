class AppRoutes {
  const AppRoutes._();

  static const login = '/login';
  static const dashboard = '/dashboard';
  static const rover = '/rover';
  static const crops = '/crops';
  static const cropDetails = '/crops/:cropId';
  static const stocks = '/stocks';
  static const notifications = '/notifications';
  static const profile = '/profile';

  static String cropDetailsPath(String cropId) {
    return '$crops/$cropId';
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
  static const notifications = 'notifications';
  static const profile = 'profile';
}
