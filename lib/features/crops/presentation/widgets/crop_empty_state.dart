import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/seedrover_mascot.dart';

class CropEmptyState extends StatelessWidget {
  const CropEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.secondaryBackground,
      borderColor: AppColors.inactiveBorder,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const SeedRoverMascot(
            expression: SeedRoverMascotExpression.emptyCurious,
            size: 88,
          ),
          const SizedBox(height: AppSpacing.md),
          Text("You're all caught up.", style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'No crop records match the current view.',
            textAlign: TextAlign.center,
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}
