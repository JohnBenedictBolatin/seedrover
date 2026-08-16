import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/animated_content.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/models/crop_model.dart';
import 'crop_detail_metric.dart';
import 'crop_plant_image.dart';

class CropDetailPanel extends StatelessWidget {
  const CropDetailPanel({
    required this.crop,
    this.actions,
    super.key,
  });

  final CropModel crop;
  final Widget? actions;

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
                    AnimatedTypingText(
                      crop.growthStage.label,
                      style: AppTypography.small,
                    ),
                  ],
                ),
              ),
              StatusBadge(label: crop.status.label, color: statusColor),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: CropPlantImage(crop: crop, size: 160),
          ),
          const SizedBox(height: AppSpacing.lg),
          _CropProgress(crop: crop, color: statusColor),
          const SizedBox(height: AppSpacing.lg),
          _OwnerDetailsGrid(crop: crop, formatDate: _formatDate),
          const SizedBox(height: AppSpacing.lg),
          if (actions != null) ...[
            actions!,
            const SizedBox(height: AppSpacing.lg),
          ],
          if (crop.notes.trim().isNotEmpty &&
              !crop.notes.contains('loaded from Supabase')) ...[
            AnimatedTypingText('Farm notes', style: AppTypography.cardTitle),
            const SizedBox(height: AppSpacing.sm),
            AnimatedTypingText(crop.notes, style: AppTypography.small),
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

class _CropProgress extends StatelessWidget {
  const _CropProgress({required this.crop, required this.color});

  final CropModel crop;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = crop.progress.clamp(0.0, 1.0).toDouble();
    final percent = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GROWTH PROGRESS', style: AppTypography.monoCaption),
                  const SizedBox(height: AppSpacing.xs),
                  Text(crop.growthStage.label, style: AppTypography.small),
                ],
              ),
            ),
            AnimatedMetricText(
              '$percent%',
              style: AppTypography.cardTitle.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: AnimatedProgressBar(
            value: progress,
            minHeight: 9,
            color: color,
            backgroundColor: AppColors.inactiveBorder,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Updates when the crop advances to a new growth stage.',
          style: AppTypography.caption.copyWith(color: AppColors.secondaryText),
        ),
      ],
    );
  }
}

class _OwnerDetailsGrid extends StatelessWidget {
  const _OwnerDetailsGrid({
    required this.crop,
    required this.formatDate,
  });

  final CropModel crop;
  final String Function(DateTime date) formatDate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 2;
        final spacing = AppSpacing.xs * (columns - 1);
        final tileWidth = (constraints.maxWidth - spacing) / columns;

        return Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            CropDetailMetric(
              width: tileWidth,
              label: 'Batch ID',
              value: crop.trackingCode,
              icon: Icons.tag_outlined,
            ),
            CropDetailMetric(
              width: tileWidth,
              label: 'Field',
              value: crop.fieldLabel,
              icon: Icons.location_on_outlined,
            ),
            CropDetailMetric(
              width: tileWidth,
              label: 'Manager',
              value: crop.managerName,
              icon: Icons.person_outline,
            ),
            CropDetailMetric(
              width: tileWidth,
              label: 'Planted',
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
              label: 'Latest Soil',
              value: crop.sensorSnapshot.recordedAt == null
                  ? 'No recent reading'
                  : '${crop.sensorSnapshot.soilMoisture.toStringAsFixed(0)}%',
              icon: Icons.water_drop_outlined,
            ),
            CropDetailMetric(
              width: tileWidth,
              label: crop.name.toLowerCase().contains('calamansi') &&
                      crop.harvestWindowStart == null
                  ? 'Next Milestone'
                  : 'Harvest',
              value: crop.harvestWindowStart == null
                  ? crop.expectedStage
                  : formatDate(crop.harvestWindowStart!),
              icon: Icons.content_cut,
            ),
          ],
        );
      },
    );
  }
}
