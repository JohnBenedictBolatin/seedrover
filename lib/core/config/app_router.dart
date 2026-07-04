import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_routes.dart';
import '../constants/permission_keys.dart';
import '../../features/authentication/presentation/screens/authenticated_home_screen.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/providers/auth_providers.dart';
import '../../features/crops/presentation/screens/crop_details_screen.dart';
import '../../features/crops/presentation/screens/crop_monitoring_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/rover/presentation/screens/rover_control_screen.dart';
import '../../shared/widgets/authenticated_scaffold.dart';
import '../../shared/widgets/feature_unavailable_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = GoRouterRefreshNotifier();

  ref.listen(authControllerProvider, (_, __) {
    refreshListenable.refresh();
  });

  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isLoggingIn = state.matchedLocation == AppRoutes.login;

      if (authState.isLoading) {
        return null;
      }

      if (!authState.isAuthenticated) {
        return isLoggingIn ? null : AppRoutes.login;
      }

      if (isLoggingIn) {
        return _initialRouteFor(authState);
      }

      final requiredPermission = _requiredPermissionFor(state.matchedLocation);

      if (requiredPermission != null &&
          !(authState.profile?.hasPermission(requiredPermission) ?? false)) {
        return _initialRouteFor(authState);
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: AppRouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: AppRouteNames.dashboard,
        builder: (context, state) => _withAuthenticatedShell(
          ref,
          state.matchedLocation,
          const DashboardScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.rover,
        name: AppRouteNames.rover,
        builder: (context, state) => _withAuthenticatedShell(
          ref,
          state.matchedLocation,
          const RoverControlScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.crops,
        name: AppRouteNames.crops,
        builder: (context, state) => _withAuthenticatedShell(
          ref,
          state.matchedLocation,
          const CropMonitoringScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.cropDetails,
        name: AppRouteNames.cropDetails,
        builder: (context, state) => _withAuthenticatedShell(
          ref,
          AppRoutes.crops,
          CropDetailsScreen(
            cropId: state.pathParameters['cropId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.stocks,
        name: AppRouteNames.stocks,
        builder: (context, state) => _withAuthenticatedShell(
          ref,
          state.matchedLocation,
          const FeatureUnavailableScreen(
            title: 'Stocks',
            message: 'Stocks will be implemented in its approved phase.',
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        name: AppRouteNames.notifications,
        builder: (context, state) => _withAuthenticatedShell(
          ref,
          state.matchedLocation,
          const FeatureUnavailableScreen(
            title: 'Notifications',
            message: 'Notifications will be handled in its own module.',
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        name: AppRouteNames.profile,
        builder: (context, state) => _withAuthenticatedShell(
          ref,
          state.matchedLocation,
          const AuthenticatedHomeScreen(
            title: 'Profile',
            message: 'Session management is active for this account.',
          ),
        ),
      ),
    ],
  );
});

String _initialRouteFor(AppAuthState authState) {
  final profile = authState.profile;

  if (profile?.hasPermission(PermissionKeys.dashboardView) ?? false) {
    return AppRoutes.dashboard;
  }

  return AppRoutes.profile;
}

String? _requiredPermissionFor(String location) {
  if (location.startsWith(AppRoutes.crops)) {
    return PermissionKeys.cropsView;
  }

  return switch (location) {
    AppRoutes.dashboard => PermissionKeys.dashboardView,
    AppRoutes.rover => PermissionKeys.roverView,
    AppRoutes.stocks => PermissionKeys.stocksView,
    AppRoutes.notifications => PermissionKeys.notificationsView,
    AppRoutes.profile => PermissionKeys.profileView,
    _ => null,
  };
}

Widget _withAuthenticatedShell(
  Ref ref,
  String currentLocation,
  Widget child,
) {
  final authState = ref.read(authControllerProvider);

  return AuthenticatedScaffold(
    currentLocation: currentLocation,
    items: _navigationItemsFor(authState),
    child: child,
  );
}

List<NavigationItemData> _navigationItemsFor(AppAuthState authState) {
  final profile = authState.profile;

  bool canView(String permissionKey) {
    return profile?.hasPermission(permissionKey) ?? false;
  }

  return [
    if (canView(PermissionKeys.dashboardView))
      const NavigationItemData(
        label: 'Dashboard',
        location: AppRoutes.dashboard,
        icon: NavigationIcons.dashboard,
      ),
    if (canView(PermissionKeys.roverView))
      const NavigationItemData(
        label: 'Rover',
        location: AppRoutes.rover,
        icon: NavigationIcons.rover,
      ),
    if (canView(PermissionKeys.cropsView))
      const NavigationItemData(
        label: 'Crops',
        location: AppRoutes.crops,
        icon: NavigationIcons.crops,
      ),
    if (canView(PermissionKeys.stocksView))
      const NavigationItemData(
        label: 'Stocks',
        location: AppRoutes.stocks,
        icon: NavigationIcons.stocks,
      ),
    if (canView(PermissionKeys.notificationsView))
      const NavigationItemData(
        label: 'Notifications',
        location: AppRoutes.notifications,
        icon: NavigationIcons.notifications,
      ),
    if (canView(PermissionKeys.profileView))
      const NavigationItemData(
        label: 'Profile',
        location: AppRoutes.profile,
        icon: NavigationIcons.profile,
      ),
  ];
}

class GoRouterRefreshNotifier extends ChangeNotifier {
  void refresh() {
    notifyListeners();
  }
}
