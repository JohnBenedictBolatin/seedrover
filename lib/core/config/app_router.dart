import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_routes.dart';
import '../constants/permission_keys.dart';
import '../constants/workspace_action.dart';
import '../theme/app_colors.dart';
import '../theme/theme_mode_controller.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/providers/auth_providers.dart';
import '../../features/crops/presentation/screens/crop_details_screen.dart';
import '../../features/crops/presentation/screens/crop_monitoring_screen.dart';
import '../../features/crops/providers/crop_providers.dart';
import '../../features/dashboard/controllers/dashboard_controller.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/inventory/providers/stock_providers.dart';
import '../../features/inventory/presentation/screens/stock_details_screen.dart';
import '../../features/inventory/presentation/screens/stock_list_screen.dart';
import '../../features/notifications/presentation/screens/notification_details_screen.dart';
import '../../features/notifications/presentation/screens/notification_list_screen.dart';
import '../../features/notifications/providers/notification_providers.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/providers/profile_providers.dart';
import '../../features/rover/presentation/screens/rover_control_screen.dart';
import '../../features/rover/providers/rover_providers.dart';
import '../../shared/widgets/authenticated_scaffold.dart';
import '../../shared/widgets/feature_unavailable_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = GoRouterRefreshNotifier();

  ref.listen(authControllerProvider, (previous, next) {
    refreshListenable.refresh();

    if (next.profile?.id != previous?.profile?.id) {
      ref.invalidate(dashboardProvider);
      ref.invalidate(dashboardRealtimeProvider);
      ref.invalidate(stockInventoryControllerProvider);
      ref.invalidate(stockSalesTrendProvider);
      ref.invalidate(cropMonitoringControllerProvider);
      ref.invalidate(notificationControllerProvider);
      ref.invalidate(profileControllerProvider);
      ref.invalidate(roverControlControllerProvider);
      ref.invalidate(plantingRunsAwaitingSyncProvider);
    }
  });

  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: refreshListenable,
    errorPageBuilder: (context, state) => _smoothPage(
      state,
      const FeatureUnavailableScreen(
        title: 'Page not found',
        message: 'This SeedRover screen is not available in the mobile app.',
      ),
    ),
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

      final profile = authState.profile;
      if (state.matchedLocation == AppRoutes.dashboard &&
          profile?.isFarmStaff == true) {
        return profile?.isInventoryStaff == true
            ? AppRoutes.stocks
            : AppRoutes.crops;
      }

      final requiredPermission = state.matchedLocation == AppRoutes.dashboard &&
              profile?.isPlantingManager == true
          ? PermissionKeys.cropsView
          : _requiredPermissionFor(state.matchedLocation);

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
              taskId: state.uri.queryParameters['task'],
              initialAction: WorkspaceAction.parse(
                state.uri.queryParameters['action'],
              ),
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
              initialAction: WorkspaceAction.parse(
                state.uri.queryParameters['action'],
              ),
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
      if (MediaQuery.disableAnimationsOf(context)) return child;
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

  if (profile?.isPlantingManager == true) {
    return AppRoutes.dashboard;
  }

  if (profile?.isPlantingStaff == true) {
    return AppRoutes.crops;
  }

  if (profile?.isInventoryStaff == true) {
    return AppRoutes.stocks;
  }

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
      final themeMode = widgetRef.watch(themeModeControllerProvider);
      AppColors.useLightPalette(themeMode == ThemeMode.light);
      return AuthenticatedScaffold(
        currentLocation: currentLocation,
        items: _navigationItemsFor(authState),
        showNavigation: currentLocation != AppRoutes.rover,
        child: child,
      );
    },
  );
}

List<NavigationItemData> _navigationItemsFor(AppAuthState authState) {
  final profile = authState.profile;

  bool canView(String permissionKey) {
    return profile?.hasPermission(permissionKey) ?? false;
  }

  final items = <NavigationItemData>[
    if (profile?.isPlantingManager == true ||
        (canView(PermissionKeys.dashboardView) &&
            profile?.isPlantingStaff != true))
      const NavigationItemData(
        label: 'Dashboard',
        location: AppRoutes.dashboard,
        icon: NavigationIcons.dashboard,
      ),
    if (canView(PermissionKeys.cropsView))
      const NavigationItemData(
        label: 'Crops',
        location: AppRoutes.crops,
        icon: NavigationIcons.crops,
      ),
    if (canView(PermissionKeys.roverView))
      const NavigationItemData(
        label: 'Rover',
        location: AppRoutes.rover,
        icon: NavigationIcons.rover,
        selectedIcon: NavigationIcons.roverSelected,
      ),
    if (canView(PermissionKeys.stocksView))
      const NavigationItemData(
        label: 'Inventory',
        location: AppRoutes.stocks,
        icon: NavigationIcons.stocks,
      ),
    if (canView(PermissionKeys.profileView))
      const NavigationItemData(
        label: 'Account',
        location: AppRoutes.profile,
        icon: NavigationIcons.profile,
      ),
  ];

  final roverIndex = items.indexWhere(
    (item) => item.location == AppRoutes.rover,
  );
  if (roverIndex >= 0) {
    final rover = items.removeAt(roverIndex);
    items.insert((items.length + 1) ~/ 2, rover);
  }
  return items;
}

class GoRouterRefreshNotifier extends ChangeNotifier {
  void refresh() {
    notifyListeners();
  }
}
