import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/crop_model.dart';
import 'crop_plant_image.dart';

class PlantedTodayCard extends StatelessWidget {
  const PlantedTodayCard({
    required this.crop,
    required this.onView,
    super.key,
  });

  final CropModel crop;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border.all(color: AppColors.primaryGreen),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            CropPlantImage(cropName: crop.name, size: 32),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'You planted ${crop.name} seeds (${crop.safeSeedCount})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.small.copyWith(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              onPressed: onView,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.cardBackground,
                foregroundColor: AppColors.primaryGreen,
                minimumSize: const Size(64, 34),
                side: const BorderSide(color: AppColors.primaryGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: Text(
                'View',
                style: AppTypography.statusBadge.copyWith(
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
