import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/animated_content.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/models/crop_model.dart';

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
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AnimatedTypingText(
                    crop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cardTitle,
                  ),
                ),
                StatusBadge(label: crop.status.label, color: statusColor),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            AnimatedTypingText(
              '${crop.plantingSource} · ${crop.fieldLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.small,
            ),
            const SizedBox(height: AppSpacing.md),
            _CropMetaRow(
              icon: Icons.straighten,
              label: 'Coverage',
              value: crop.fieldAreaM2 == null
                  ? '${crop.completedDrops} completed drops'
                  : '${crop.fieldAreaM2!.toStringAsFixed(2)} m² · ${crop.completedDrops} drops',
            ),
            const SizedBox(height: AppSpacing.sm),
            _CropMetaRow(
              icon: Icons.grain,
              label: 'Est. seeds',
              value: crop.estimatedSeedMin == null
                  ? 'Not available'
                  : '${crop.estimatedSeedMin}-${crop.estimatedSeedMax ?? crop.estimatedSeedMin}',
            ),
            const SizedBox(height: AppSpacing.sm),
            _CropMetaRow(
              icon: Icons.water_drop_outlined,
              label: 'Latest soil',
              value: crop.sensorSnapshot.recordedAt == null
                  ? 'No linked reading'
                  : '${crop.sensorSnapshot.soilMoisture.toStringAsFixed(0)}%',
            ),
            const SizedBox(height: AppSpacing.sm),
            _CropMetaRow(
              icon: Icons.content_cut,
              label: crop.name.toLowerCase().contains('calamansi') &&
                      crop.harvestWindowStart == null
                  ? 'Nursery'
                  : 'Harvest',
              value: crop.harvestWindowStart == null
                  ? crop.expectedStage
                  : '${_formatDate(crop.harvestWindowStart!)}-${_formatDate(crop.harvestWindowEnd ?? crop.harvestWindowStart!)} · ${crop.forecastConfidence}',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(crop.careStatus,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.small),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: AnimatedProgressBar(
                value: crop.progress,
                minHeight: 6,
                color: statusColor,
                backgroundColor: AppColors.inactiveBorder,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AnimatedTypingText(
              crop.growthStage.label,
              style: AppTypography.monoCaption.copyWith(color: statusColor),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(CropStatus status) {
    return switch (status) {
      CropStatus.healthy => AppColors.success,
      CropStatus.needsWater => AppColors.warning,
      CropStatus.needsFertilizer => AppColors.warning,
      CropStatus.readyForHarvest => AppColors.primaryGreen,
      CropStatus.harvested => AppColors.mutedText,
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

class _CropMetaRow extends StatelessWidget {
  const _CropMetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.mutedText),
        const SizedBox(width: AppSpacing.sm),
        AnimatedTypingText(label, style: AppTypography.caption),
        const Spacer(),
        AnimatedTypingText(
          value,
          textAlign: TextAlign.end,
          style: AppTypography.monoCaption,
        ),
      ],
    );
  }
}
