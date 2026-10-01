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
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.sageSurface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  Icons.eco_rounded,
                  size: 18,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.cardTitle.copyWith(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final crop in crops) ...[
          _CropListTile(crop: crop, onTap: () => onCropSelected(crop)),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _CropListTile extends StatelessWidget {
  const _CropListTile({required this.crop, required this.onTap});

  final CropModel crop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (crop.status) {
      CropStatus.active => AppColors.information,
      CropStatus.needsAttention => AppColors.warning,
      CropStatus.readyForHarvest => AppColors.success,
      CropStatus.harvested => AppColors.secondaryText,
      CropStatus.notHarvested => AppColors.danger,
    };
    final statusLabel = switch (crop.status) {
      CropStatus.active => 'Active',
      CropStatus.needsAttention => 'Needs attention',
      CropStatus.readyForHarvest => 'Ready for harvest',
      CropStatus.harvested => 'Harvested',
      CropStatus.notHarvested => 'Not harvested',
    };

    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;

    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.secondaryBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: AppColors.inactiveBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.smd,
          ),
          child: largeText
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _CropThumbnail(crop: crop),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                crop.trackingCode,
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryText,
                                ),
                              ),
                              Text(
                                crop.fieldLabel,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 16, color: AppColors.secondaryText),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 54),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recorded stage: ${crop.recordedGrowthStage?.trim().isNotEmpty == true ? crop.recordedGrowthStage : 'Not recorded'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption,
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _CropStatusBadge(
                              label: statusLabel,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    _CropThumbnail(crop: crop),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  crop.trackingCode,
                                  style: AppTypography.body.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            crop.fieldLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption,
                          ),
                          Text(
                            'Recorded stage: ${crop.recordedGrowthStage?.trim().isNotEmpty == true ? crop.recordedGrowthStage : 'Not recorded'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption,
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _CropStatusBadge(
                              label: statusLabel,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 16, color: AppColors.secondaryText),
                  ],
                ),
        ),
      ),
    );
  }
}

class _CropStatusBadge extends StatelessWidget {
  const _CropStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _CropThumbnail extends StatelessWidget {
  const _CropThumbnail({required this.crop});

  final CropModel crop;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: SizedBox.square(
          dimension: 46,
          child: ColoredBox(
            color: AppColors.cardBackground,
            child: CropPlantImage(crop: crop, size: 42),
          ),
        ),
      );
}
