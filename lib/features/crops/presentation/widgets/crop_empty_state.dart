import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';

class CropEmptyState extends StatelessWidget {
  const CropEmptyState({
    required this.onClearFilters,
    super.key,
  });

  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.secondaryBackground,
      borderColor: AppColors.inactiveBorder,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Icon(
            Icons.spa_outlined,
            color: AppColors.primaryGreen,
            size: 36,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('No crops found', style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Adjust your search or filters to show crop records.',
            textAlign: TextAlign.center,
            style: AppTypography.small,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onClearFilters,
            icon: const Icon(Icons.refresh),
            label: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }
}
