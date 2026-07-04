import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
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
    final sortedRecords = [...records]
      ..sort((left, right) => right.performedAt.compareTo(left.performedAt));

    return Column(
      children: [
        for (final record in sortedRecords)
          _MaintenanceRecordTile(record: record),
      ],
    );
  }
}

class _MaintenanceRecordTile extends StatelessWidget {
  const _MaintenanceRecordTile({required this.record});

  final CropMaintenanceRecord record;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.circle,
            size: 10,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.activity.label,
                        style: AppTypography.small.copyWith(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _formatDateTime(record.performedAt),
                      style: AppTypography.monoCaption,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(record.notes, style: AppTypography.small),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'By ${record.performedBy}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '${date.month}/${date.day}/${date.year} $hour:$minute';
  }
}
