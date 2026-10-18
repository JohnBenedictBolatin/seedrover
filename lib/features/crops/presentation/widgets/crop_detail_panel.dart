import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/farmer_friendly_copy.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../data/models/crop_model.dart';

class CropDetailPanel extends StatelessWidget {
  const CropDetailPanel({
    required this.crop,
    this.onRecordCare,
    super.key,
  });

  final CropModel crop;
  final VoidCallback? onRecordCare;

  @override
  Widget build(BuildContext context) {
    final nextTask = crop.nextCareTask;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final gap = AppSpacing.xs;
              final tileWidth = (constraints.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  _OverviewFact(
                    width: tileWidth,
                    label: 'Planted',
                    value: DateTimeFormatter.formatDate(crop.plantingDate),
                    icon: Icons.event_outlined,
                  ),
                  _OverviewFact(
                    width: tileWidth,
                    label: 'Growth stage',
                    value: crop.recordedGrowthStage?.trim().isNotEmpty == true
                        ? FarmerFriendlyCopy.growthStage(
                            crop.recordedGrowthStage!)
                        : 'Not recorded',
                    icon: Icons.eco_outlined,
                  ),
                  _OverviewFact(
                    width: tileWidth,
                    label: 'Planted by',
                    value: crop.managerName.trim().isEmpty
                        ? 'Unassigned'
                        : crop.managerName,
                    icon: Icons.person_outline_rounded,
                  ),
                  _OverviewFact(
                    width: tileWidth,
                    label: 'Next care',
                    value: nextTask == null
                        ? 'No task scheduled'
                        : FarmerFriendlyCopy.careTask(
                            _compactCareTaskTitle(nextTask.title, crop.name)),
                    icon: nextTask?.status == 'Overdue'
                        ? Icons.warning_amber_rounded
                        : Icons.task_alt_rounded,
                    accentColor: nextTask?.status == 'Overdue'
                        ? AppColors.warning
                        : null,
                  ),
                  _OverviewFact(
                    width: tileWidth,
                    label: 'Planting location',
                    value: crop.location.trim().isEmpty
                        ? 'Not recorded'
                        : crop.location,
                    icon: Icons.location_on_outlined,
                  ),
                  _OverviewFact(
                    width: tileWidth,
                    label: 'Planting cycles',
                    value: _plantingDropLabel(crop),
                    icon: Icons.water_drop_outlined,
                  ),
                ],
              );
            },
          ),
          if (onRecordCare != null) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: onRecordCare,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Record care'),
            ),
          ],
        ],
      ),
    );
  }
}

String _plantingDropLabel(CropModel crop) {
  final completed = crop.plantingCompletedDrops;
  final target = crop.plantingTargetDrops;
  if (completed == null && target == null) return 'Not recorded';
  if (completed == null) return '$target planned cycles';
  if (target == null) return '$completed completed cycles';
  return '$completed of $target cycles';
}

String _compactCareTaskTitle(String title, String cropName) {
  final cleanTitle = title.trim();
  final suffix = 'for ${cropName.trim()}';
  final prefixEnd = cleanTitle.length - suffix.length;
  if (prefixEnd > 0 &&
      cleanTitle[prefixEnd - 1].trim().isEmpty &&
      cleanTitle.substring(prefixEnd).toLowerCase() == suffix.toLowerCase()) {
    return cleanTitle.substring(0, prefixEnd).trimRight();
  }
  return cleanTitle;
}

class _OverviewFact extends StatelessWidget {
  const _OverviewFact({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon,
                      color: accentColor ?? AppColors.primaryGreen, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(label, style: AppTypography.caption)),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(value,
                  style: AppTypography.small
                      .copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
}
