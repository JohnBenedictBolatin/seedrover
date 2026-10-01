import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/models/crop_model.dart';
import 'crop_plant_image.dart';

class CropCard extends StatelessWidget {
  const CropCard({
    required this.crop,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final CropModel crop;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(crop.status);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: AppCard(
        backgroundColor: AppColors.secondaryBackground,
        borderColor:
            selected ? AppColors.primaryGreen : AppColors.inactiveBorder,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.smd, vertical: AppSpacing.sm),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.sageSurface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: CropPlantImage(crop: crop, size: 44),
              ),
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(crop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text('${crop.fieldLabel} · ${crop.growthStageLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.small),
                  Text(crop.trackingCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.numericCaption
                          .copyWith(color: AppColors.primaryGreen)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(label: crop.status.label, color: statusColor),
                if (crop.harvestWindowStart != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(_formatDate(crop.harvestWindowStart!),
                      style: AppTypography.numericCaption),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(CropStatus status) {
    return switch (status) {
      CropStatus.active => AppColors.mutedText,
      CropStatus.needsAttention => AppColors.warning,
      CropStatus.readyForHarvest => AppColors.primaryGreen,
      CropStatus.harvested => AppColors.mutedText,
      CropStatus.notHarvested => AppColors.danger,
    };
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
