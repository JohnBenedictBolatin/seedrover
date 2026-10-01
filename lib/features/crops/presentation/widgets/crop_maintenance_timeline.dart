import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/history_pagination.dart';
import '../../data/models/crop_model.dart';

class CropActivityHistory extends StatefulWidget {
  const CropActivityHistory({required this.records, super.key});

  final List<CropMaintenanceRecord> records;

  @override
  State<CropActivityHistory> createState() => _CropActivityHistoryState();
}

class _CropActivityHistoryState extends State<CropActivityHistory> {
  static const _pageSize = 5;
  int _pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final records = [...widget.records]
      ..sort((left, right) => right.performedAt.compareTo(left.performedAt));
    final pageCount = (records.length / _pageSize).ceil();
    final pageIndex = pageCount == 0 ? 0 : _pageIndex.clamp(0, pageCount - 1);
    final start = pageIndex * _pageSize;
    final visibleRecords = records.skip(start).take(_pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child:
                  Text('Activity history', style: AppTypography.sectionHeading),
            ),
            _RecordCount(count: records.length),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (records.length > _pageSize)
          HistoryPagination(
            pageIndex: pageIndex,
            totalRecords: records.length,
            pageSize: _pageSize,
            onPageChanged: (page) => setState(() => _pageIndex = page),
          ),
        if (records.isEmpty)
          Container(
            constraints: const BoxConstraints(minHeight: 112),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              border: Border.all(color: AppColors.inactiveBorder),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_rounded,
                    color: AppColors.mutedText, size: 28),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'No activities have been recorded for this crop.',
                  textAlign: TextAlign.center,
                  style: AppTypography.small,
                ),
              ],
            ),
          )
        else ...[
          for (var index = 0; index < visibleRecords.length; index++) ...[
            _ActivityHistoryRow(
              record: visibleRecords[index],
              key: ValueKey(visibleRecords[index].id ??
                  '${visibleRecords[index].performedAt.toIso8601String()}-$index'),
            ),
            if (index < visibleRecords.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }
}

class _RecordCount extends StatelessWidget {
  const _RecordCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Text(
          '$count ${count == 1 ? 'record' : 'records'}',
          style: AppTypography.caption.copyWith(
            color: AppColors.primaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _ActivityHistoryRow extends StatelessWidget {
  const _ActivityHistoryRow({required this.record, super.key});

  final CropMaintenanceRecord record;

  @override
  Widget build(BuildContext context) {
    final performedAt = record.performedAt.toLocal();
    final detail = _activityDetails(record);
    final note = _cleanNote(record.notes);
    final color = _activityColor(record.activity);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border.all(color: AppColors.inactiveBorder),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(_activityIcon(record.activity), color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.activity.label,
                  style: AppTypography.body.copyWith(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDate(performedAt)} · ${_formatTime(performedAt)} · ${record.performedBy}',
                  style: AppTypography.caption,
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(detail, style: AppTypography.small),
                ],
                if (note.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(note, style: AppTypography.small),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _activityDetails(CropMaintenanceRecord record) {
  final details = <String>[];
  if (record.source == 'Rover' &&
      record.activity == CropMaintenanceActivity.planted) {
    final cycleMatch = RegExp(
      r'(\d+)\s+of\s+(\d+)\s+planned\s+(?:planting\s+)?(?:gate cycles|gate pulses)\s+completed\.?',
      caseSensitive: false,
    ).firstMatch(record.notes);
    details.add(cycleMatch != null
        ? '${cycleMatch.group(1)} of ${cycleMatch.group(2)} planting cycles completed'
        : record.quantity != null
            ? '${_formatQuantity(record)} planting cycles recorded'
            : 'Planting run recorded');
  } else if (record.quantity != null) {
    details.add(_formatQuantity(record));
  }
  if (record.material?.trim().isNotEmpty == true) {
    details.add(record.material!.trim());
  }
  if (record.observedStage?.trim().isNotEmpty == true) {
    details.add('Stage: ${record.observedStage!.trim()}');
  }
  return details.join(' · ');
}

String _cleanNote(String value) {
  if (value.trim() == 'No notes were added.') return '';
  return value
      .replaceAll(
          RegExp(r'seed count is estimated\.?', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[.\s]+$'), '')
      .trim();
}

String _formatQuantity(CropMaintenanceRecord record) {
  final quantity = record.quantity!;
  final value = quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 2);
  final unit = record.unit?.trim();
  return unit == null || unit.isEmpty ? value : '$value $unit';
}

String _formatDate(DateTime date) =>
    '${date.month}/${date.day}/${date.year.toString().substring(2)}';

String _formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final marker = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $marker';
}

Color _activityColor(CropMaintenanceActivity activity) => switch (activity) {
      CropMaintenanceActivity.planted ||
      CropMaintenanceActivity.stageObserved ||
      CropMaintenanceActivity.transplanted =>
        AppColors.primaryGreen,
      CropMaintenanceActivity.watered => AppColors.information,
      CropMaintenanceActivity.fertilized => AppColors.warning,
      CropMaintenanceActivity.inspected => AppColors.primaryText,
      CropMaintenanceActivity.harvested ||
      CropMaintenanceActivity.notHarvested ||
      CropMaintenanceActivity.plantingFailed =>
        AppColors.danger,
    };

IconData _activityIcon(CropMaintenanceActivity activity) => switch (activity) {
      CropMaintenanceActivity.planted => Icons.eco_outlined,
      CropMaintenanceActivity.watered => Icons.water_drop_outlined,
      CropMaintenanceActivity.fertilized => Icons.science_outlined,
      CropMaintenanceActivity.inspected => Icons.visibility_outlined,
      CropMaintenanceActivity.stageObserved => Icons.timeline_rounded,
      CropMaintenanceActivity.transplanted => Icons.eco_outlined,
      CropMaintenanceActivity.harvested => Icons.agriculture_outlined,
      CropMaintenanceActivity.notHarvested => Icons.cancel_outlined,
      CropMaintenanceActivity.plantingFailed => Icons.error_outline,
    };
