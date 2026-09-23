import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/animated_content.dart';
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
              crop.trackingCode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.monoCaption.copyWith(
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: CropPlantImage(crop: crop, size: 64),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _CropMetaRow(
              icon: Icons.place_outlined,
              label: 'Field',
              value: crop.fieldLabel,
            ),
            const SizedBox(height: AppSpacing.sm),
            _CropMetaRow(
              icon: Icons.checklist_outlined,
              label: 'Stage',
              value: crop.growthStage.label,
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
                  : '${_formatDate(crop.harvestWindowStart!)}-${_formatDate(crop.harvestWindowEnd ?? crop.harvestWindowStart!)}',
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
                  side: BorderSide(color: AppColors.primaryGreen),
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
      CropStatus.healthy => AppColors.success,
      CropStatus.needsWater => AppColors.warning,
      CropStatus.needsFertilizer => AppColors.warning,
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
        Flexible(
          child: AnimatedTypingText(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: AppTypography.monoCaption,
          ),
        ),
      ],
    );
  }
}
