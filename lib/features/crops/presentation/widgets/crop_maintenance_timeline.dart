import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/crop_model.dart';

class CropMaintenanceTimeline extends StatelessWidget {
  const CropMaintenanceTimeline({
    required this.records,
    super.key,
  });

  final List<CropMaintenanceRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Text('No maintenance records yet.', style: AppTypography.small);
    }

    final sortedRecords = [...records]
      ..sort((left, right) => right.performedAt.compareTo(left.performedAt));

    return Column(
      children: [
        for (final record in sortedRecords) ...[
          _MaintenanceRecordTile(record: record),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _MaintenanceRecordTile extends StatelessWidget {
  const _MaintenanceRecordTile({required this.record});

  final CropMaintenanceRecord record;

  @override
  Widget build(BuildContext context) {
    final color = _activityColor(record.activity);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Icon(_activityIcon(record.activity), color: color, size: 18),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                0,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.activity.label,
                          style: AppTypography.statusBadge.copyWith(
                            color: color,
                          ),
                        ),
                      ),
                      Text(
                        _formatDate(record.performedAt),
                        style: AppTypography.monoCaption.copyWith(color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(record.notes, style: AppTypography.small),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _formatTime(record.performedAt),
                    style: AppTypography.monoCaption,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'By ${record.performedBy}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _activityColor(CropMaintenanceActivity activity) {
    return switch (activity) {
      CropMaintenanceActivity.planted => AppColors.primaryGreen,
      CropMaintenanceActivity.watered => AppColors.information,
      CropMaintenanceActivity.fertilized => AppColors.warning,
      CropMaintenanceActivity.inspected => AppColors.primaryText,
      CropMaintenanceActivity.harvested => AppColors.danger,
    };
  }

  IconData _activityIcon(CropMaintenanceActivity activity) {
    return switch (activity) {
      CropMaintenanceActivity.planted => Icons.eco_outlined,
      CropMaintenanceActivity.watered => Icons.water_drop_outlined,
      CropMaintenanceActivity.fertilized => Icons.science_outlined,
      CropMaintenanceActivity.inspected => Icons.visibility_outlined,
      CropMaintenanceActivity.harvested => Icons.agriculture_outlined,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year.toString().substring(2)}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final marker = date.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $marker';
  }
}
