import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/crop_model.dart';
import 'crop_plant_image.dart';

class PlantedCropGroup extends StatelessWidget {
  const PlantedCropGroup({
    required this.title,
    required this.crops,
    required this.onCropSelected,
    super.key,
  });

  final String title;
  final List<CropModel> crops;
  final ValueChanged<CropModel> onCropSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cardTitle.copyWith(
                  color: AppColors.primaryText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final crop in crops)
              SizedBox(
                width: 128,
                child: _PlantedCropTile(
                  crop: crop,
                  onTap: () => onCropSelected(crop),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PlantedCropTile extends StatelessWidget {
  const _PlantedCropTile({
    required this.crop,
    required this.onTap,
  });

  final CropModel crop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(crop.status);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border.all(color: AppColors.inactiveBorder),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Text(
              'ID: ${crop.id.replaceFirst('crop-', 'PN-')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.monoCaption.copyWith(
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            CropPlantImage(cropName: crop.name, size: 52),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${crop.name} (${crop.safeSeedCount})',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              crop.status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.monoCaption.copyWith(color: color),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              crop.growthStage.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.monoCaption.copyWith(color: color),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _formatDate(crop.plantingDate),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.monoCaption,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.cardBackground,
                  foregroundColor: AppColors.primaryGreen,
                  minimumSize: const Size.fromHeight(32),
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
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(CropStatus status) {
    return switch (status) {
      CropStatus.healthy => AppColors.primaryGreen,
      CropStatus.needsWater => AppColors.warning,
      CropStatus.needsFertilizer => AppColors.warning,
      CropStatus.readyForHarvest => AppColors.success,
      CropStatus.harvested => AppColors.mutedText,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year.toString().substring(2)}';
  }
}
