import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/theme_mode_controller.dart';
import 'app_router.dart';
import '../services/push_notification_service.dart';
import '../../features/authentication/providers/auth_providers.dart';
import '../../shared/widgets/connectivity_status.dart';

class SeedRoverApp extends ConsumerWidget {
  const SeedRoverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final authState = ref.watch(authControllerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final lightTheme = AppTheme.light;
    final darkTheme = AppTheme.dark;
    AppColors.useLightPalette(themeMode == ThemeMode.light);
    PushNotificationService.instance.setNavigationHandler(
      isAuthenticated: authState.isAuthenticated,
      onNavigate: (route) => router.go(route),
    );

    return MaterialApp.router(
      title: 'SeedRover',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => ConnectivityStatus(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
