import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_routes.dart';
import '../constants/permission_keys.dart';
import '../../features/assistant/presentation/widgets/assistant_floating_button.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/providers/auth_providers.dart';
import '../../features/crops/presentation/screens/crop_details_screen.dart';
import '../../features/crops/presentation/screens/crop_monitoring_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/inventory/presentation/screens/stock_details_screen.dart';
import '../../features/inventory/presentation/screens/stock_list_screen.dart';
import '../../features/notifications/providers/notification_providers.dart';
import '../../features/notifications/presentation/screens/notification_details_screen.dart';
import '../../features/notifications/presentation/screens/notification_list_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/user_details_screen.dart';
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
        pageBuilder: (context, state) => _smoothPage(
          state,
          const LoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: AppRouteNames.dashboard,
        pageBuilder: (context, state) => _smoothPage(
          state,
          _withAuthenticatedShell(
            ref,
            state.matchedLocation,
            const DashboardScreen(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.rover,
        name: AppRouteNames.rover,
        pageBuilder: (context, state) => _smoothPage(
          state,
          _withAuthenticatedShell(
            ref,
            state.matchedLocation,
            const RoverControlScreen(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.crops,
        name: AppRouteNames.crops,
        pageBuilder: (context, state) => _smoothPage(
          state,
          _withAuthenticatedShell(
            ref,
            state.matchedLocation,
            const CropMonitoringScreen(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.cropDetails,
        name: AppRouteNames.cropDetails,
        pageBuilder: (context, state) => _smoothPage(
          state,
          _withAuthenticatedShell(
            ref,
            AppRoutes.crops,
            CropDetailsScreen(
              cropId: state.pathParameters['cropId'] ?? '',
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.stocks,
        name: AppRouteNames.stocks,
        pageBuilder: (context, state) => _smoothPage(
          state,
          _withAuthenticatedShell(
            ref,
            state.matchedLocation,
            const StockListScreen(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.stockDetails,
        name: AppRouteNames.stockDetails,
        pageBuilder: (context, state) => _smoothPage(
          state,
          _withAuthenticatedShell(
            ref,
            AppRoutes.stocks,
            StockDetailsScreen(
              stockId: state.pathParameters['stockId'] ?? '',
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        name: AppRouteNames.notifications,
        pageBuilder: (context, state) => _smoothPage(
          state,
          _withAuthenticatedShell(
            ref,
            state.matchedLocation,
            const NotificationListScreen(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.notificationDetails,
        name: AppRouteNames.notificationDetails,
        pageBuilder: (context, state) => _smoothPage(
          state,
          _withAuthenticatedShell(
            ref,
            AppRoutes.notifications,
            NotificationDetailsScreen(
              notificationId: state.pathParameters['notificationId'] ?? '',
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.plantingLogDetails,
        name: AppRouteNames.plantingLogDetails,
        pageBuilder: (context, state) => _smoothPage(
          state,
          _withAuthenticatedShell(
            ref,
            AppRoutes.rover,
            const FeatureUnavailableScreen(
              title: 'Planting Log',
              message: 'Planting log details will be enabled in a later phase.',
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.userDetails,
        name: AppRouteNames.userDetails,
        pageBuilder: (context, state) => _smoothPage(
          state,
          _withAuthenticatedShell(
            ref,
            AppRoutes.profile,
            UserDetailsScreen(
              userId: state.pathParameters['userId'] ?? '',
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        name: AppRouteNames.profile,
        pageBuilder: (context, state) => _smoothPage(
          state,
          _withAuthenticatedShell(
            ref,
            state.matchedLocation,
            const ProfileScreen(),
          ),
        ),
      ),
    ],
  );
});

CustomTransitionPage<void> _smoothPage(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final secondaryCurve = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.02, 0),
            ).animate(secondaryCurve),
            child: child,
          ),
        ),
      );
    },
  );
}

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

  if (location.startsWith(AppRoutes.stocks)) {
    return PermissionKeys.stocksView;
  }

  if (location.startsWith(AppRoutes.notifications)) {
    return PermissionKeys.notificationsView;
  }

  if (location.startsWith('/planting-logs')) {
    return PermissionKeys.roverPlantingControl;
  }

  if (location.startsWith('/users')) {
    return PermissionKeys.usersView;
  }

  return switch (location) {
    AppRoutes.dashboard => PermissionKeys.dashboardView,
    AppRoutes.rover => PermissionKeys.roverView,
    AppRoutes.profile => PermissionKeys.profileView,
    _ => null,
  };
}

Widget _withAuthenticatedShell(
  Ref ref,
  String currentLocation,
  Widget child,
) {
  return Consumer(
    builder: (context, widgetRef, _) {
      final authState = widgetRef.watch(authControllerProvider);
      final unreadNotificationCount =
          widgetRef.watch(notificationControllerProvider).unreadCount;

      return AuthenticatedScaffold(
        currentLocation: currentLocation,
        items: _navigationItemsFor(authState, unreadNotificationCount),
        floatingAction: const AssistantFloatingButton(),
        child: child,
      );
    },
  );
}

List<NavigationItemData> _navigationItemsFor(
  AppAuthState authState,
  int unreadNotificationCount,
) {
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
      NavigationItemData(
        label: 'Notifications',
        location: AppRoutes.notifications,
        icon: NavigationIcons.notifications,
        badgeCount: unreadNotificationCount,
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
