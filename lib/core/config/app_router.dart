import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

final appRouterProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: AppRoutes.dashboard,
    routes: [
      GoRoute(
        path: AppRoutes.dashboard,
        name: AppRouteNames.dashboard,
        builder: (context, state) => const _FoundationRouteView(
          title: 'SeedRover',
          label: 'Phase 1 Foundation',
        ),
      ),
    ],
  ),
);

class _FoundationRouteView extends StatelessWidget {
  const _FoundationRouteView({
    required this.title,
    required this.label,
  });

  final String title;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.screenTitle),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: AppTypography.body.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
