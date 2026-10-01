import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/models/crop_model.dart';

class CropGrowthProgress extends StatelessWidget {
  const CropGrowthProgress({required this.crop, super.key});

  final CropModel crop;

  @override
  Widget build(BuildContext context) {
    final stages = crop.profileStages;
    final stageIndex = _findStageIndex(stages, crop.growthStageLabel);
    final available = stages.isNotEmpty && stageIndex >= 0;
    final progress = available ? (stageIndex + 1) / stages.length : null;

    return AppCard(
      backgroundColor: AppColors.secondaryBackground,
      borderColor: AppColors.inactiveBorder,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Growth progress',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      crop.growthStageLabel,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (progress != null)
                Text(
                  '${(progress * 100).round()}%',
                  style: AppTypography.numericValue.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (progress != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.cardBackground,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Stage ${stageIndex + 1} of ${stages.length} · based on the recorded stage',
              style: AppTypography.caption,
            ),
          ] else
            Text(
              stages.isEmpty
                  ? 'Progress unavailable · no crop stage plan recorded'
                  : 'Progress unavailable · recorded stage is not in this crop’s stage plan',
              style: AppTypography.caption,
            ),
        ],
      ),
    );
  }
}

int _findStageIndex(List<String> stages, String currentStage) {
  final normalized = currentStage.trim().toLowerCase();
  final exact = stages.indexWhere(
    (stage) => stage.trim().toLowerCase() == normalized,
  );
  if (exact >= 0) return exact;

  return stages.indexWhere((stage) {
    final candidate = stage.trim().toLowerCase();
    return normalized.contains(candidate) || candidate.contains(normalized);
  });
}
