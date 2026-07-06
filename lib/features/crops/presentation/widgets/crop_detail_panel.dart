import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/animated_content.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/models/crop_model.dart';
import 'crop_detail_metric.dart';
import 'crop_maintenance_note.dart';
import 'crop_plant_image.dart';

class CropDetailPanel extends StatelessWidget {
  const CropDetailPanel({
    required this.crop,
    this.actions,
    this.onViewGrowthTimeline,
    super.key,
  });

  final CropModel crop;
  final Widget? actions;
  final VoidCallback? onViewGrowthTimeline;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(crop.status);

    return AppCard(
      backgroundColor: AppColors.secondaryBackground,
      borderColor: AppColors.inactiveBorder,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedTypingText(
                      crop.name,
                      style: AppTypography.sectionHeading,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AnimatedTypingText(crop.variety, style: AppTypography.small),
                  ],
                ),
              ),
              StatusBadge(label: crop.status.label, color: statusColor),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: CropPlantImage(cropName: crop.name, size: 160),
          ),
          const SizedBox(height: AppSpacing.lg),
          _ProgressHeader(
            crop: crop,
            color: statusColor,
            onViewGrowthTimeline: onViewGrowthTimeline,
          ),
          const SizedBox(height: AppSpacing.lg),
          _PlantingDetailsGrid(crop: crop, formatDate: _formatDate),
          const SizedBox(height: AppSpacing.lg),
          if (actions != null) ...[
            actions!,
            const SizedBox(height: AppSpacing.lg),
          ],
          AnimatedTypingText('Notes', style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.sm),
          AnimatedTypingText(crop.notes, style: AppTypography.small),
          const SizedBox(height: AppSpacing.lg),
          AnimatedTypingText(
            'Maintenance Notes',
            style: AppTypography.cardTitle,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final note in crop.maintenanceNotes) ...[
            CropMaintenanceNote(note: note),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
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
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year.toString().substring(2);

    return '$month/$day/$year';
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.crop,
    required this.color,
    required this.onViewGrowthTimeline,
  });

  final CropModel crop;
  final Color color;
  final VoidCallback? onViewGrowthTimeline;

  @override
  Widget build(BuildContext context) {
    final progress = (crop.progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AnimatedTypingText('Crop Progress', style: AppTypography.small),
            if (onViewGrowthTimeline != null) ...[
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                tooltip: 'View growth timeline',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                onPressed: onViewGrowthTimeline,
                icon: const Icon(
                  Icons.info_outline,
                  color: AppColors.primaryText,
                  size: 17,
                ),
              ),
            ],
            const Spacer(),
            AnimatedMetricText(
              '$progress%',
              style: AppTypography.sensorValue.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: AnimatedProgressBar(
            value: crop.progress,
            minHeight: 8,
            color: color,
            backgroundColor: AppColors.inactiveBorder,
          ),
        ),
      ],
    );
  }
}

class _PlantingDetailsGrid extends StatelessWidget {
  const _PlantingDetailsGrid({
    required this.crop,
    required this.formatDate,
  });

  final CropModel crop;
  final String Function(DateTime date) formatDate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 3;
        final spacing = AppSpacing.xs * (columns - 1);
        final tileWidth = (constraints.maxWidth - spacing) / columns;

        return Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            CropDetailMetric(
              width: tileWidth,
              label: 'Crop ID',
              value: crop.id,
              icon: Icons.tag_outlined,
            ),
            CropDetailMetric(
              width: tileWidth,
              label: 'Quantity',
              value: '${crop.safeSeedCount}',
              icon: Icons.spa_outlined,
            ),
            CropDetailMetric(
              width: tileWidth,
              label: 'Plant Date',
              value: formatDate(crop.plantingDate),
              icon: Icons.event_outlined,
            ),
            CropDetailMetric(
              width: tileWidth,
              label: 'Stage',
              value: crop.growthStage.label,
              icon: Icons.timeline,
            ),
            CropDetailMetric(
              width: tileWidth,
              label: 'Est. Harv',
              value: formatDate(crop.estimatedHarvest),
              icon: Icons.content_cut,
            ),
            CropDetailMetric(
              width: tileWidth,
              label: 'Staff',
              value: crop.managerName,
              icon: Icons.person_outline,
            ),
          ],
        );
      },
    );
  }
}
