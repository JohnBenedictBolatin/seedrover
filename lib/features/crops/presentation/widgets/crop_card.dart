import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
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
        borderColor: selected ? AppColors.primaryGreen : AppColors.inactiveBorder,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
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
            Text(
              crop.variety,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.small,
            ),
            const SizedBox(height: AppSpacing.md),
            _CropMetaRow(
              icon: Icons.event_outlined,
              label: 'Planted',
              value: _formatDate(crop.plantingDate),
            ),
            const SizedBox(height: AppSpacing.sm),
            _CropMetaRow(
              icon: Icons.content_cut,
              label: 'Harvest',
              value: _formatDate(crop.estimatedHarvest),
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: LinearProgressIndicator(
                value: crop.progress,
                minHeight: 6,
                color: statusColor,
                backgroundColor: AppColors.inactiveBorder,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
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
        Text(label, style: AppTypography.caption),
        const Spacer(),
        Text(value, style: AppTypography.monoCaption),
      ],
    );
  }
}
