import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/seedrover_mascot.dart';

class StockEmptyState extends StatelessWidget {
  const StockEmptyState({super.key});

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
          Text('No inventory items yet.', style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Inventory items added to your workspace will appear here.',
            textAlign: TextAlign.center,
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}
