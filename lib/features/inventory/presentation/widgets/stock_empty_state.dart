import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/seedrover_mascot.dart';

class StockEmptyState extends StatelessWidget {
  const StockEmptyState({
    required this.onClearFilters,
    super.key,
  });

  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: AppColors.inactiveBorder,
      backgroundColor: AppColors.secondaryBackground,
      child: Column(
        children: [
          const SeedRoverMascot(
            expression: SeedRoverMascotExpression.emptyCurious,
            size: 88,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('No inventory items found.', style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Clear a filter to check the available stock records again.',
            textAlign: TextAlign.center,
            style: AppTypography.small,
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: onClearFilters,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              side: const BorderSide(color: AppColors.primaryGreen),
            ),
            child: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }
}
