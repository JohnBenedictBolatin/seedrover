import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/seedrover_mascot.dart';

class NotificationEmptyState extends StatelessWidget {
  const NotificationEmptyState({
    required this.hasNotifications,
    required this.hasActiveFilters,
    this.onClearFilters,
    this.emptyTitle,
    this.emptyDescription,
    super.key,
  });

  final bool hasNotifications;
  final bool hasActiveFilters;
  final VoidCallback? onClearFilters;
  final String? emptyTitle;
  final String? emptyDescription;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border.all(color: AppColors.inactiveBorder),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const SeedRoverMascot(
              expression: SeedRoverMascotExpression.emptyCurious,
              size: 88,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              hasActiveFilters
                  ? 'No matching notifications'
                  : emptyTitle ??
                      (hasNotifications
                          ? 'No matching notifications'
                          : 'No notifications yet'),
              textAlign: TextAlign.center,
              style: AppTypography.cardTitle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              hasActiveFilters
                  ? 'Try changing your search or filters.'
                  : emptyDescription ??
                      (hasNotifications
                          ? 'Try changing your search or filters.'
                          : 'New updates will appear here.'),
              textAlign: TextAlign.center,
              style: AppTypography.caption,
            ),
            if (hasActiveFilters)
              TextButton(
                onPressed: onClearFilters,
                child: const Text('Clear filters'),
              ),
          ],
        ),
      ),
    );
  }
}
