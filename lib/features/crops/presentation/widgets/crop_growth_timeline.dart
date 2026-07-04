import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/crop_model.dart';

class CropGrowthTimeline extends StatelessWidget {
  const CropGrowthTimeline({
    required this.currentStage,
    super.key,
  });

  final CropGrowthStage currentStage;

  @override
  Widget build(BuildContext context) {
    final currentIndex = CropGrowthStage.values.indexOf(currentStage);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var index = 0; index < CropGrowthStage.values.length; index++)
              _GrowthStageTile(
                width: (constraints.maxWidth - AppSpacing.sm) / 2,
                stage: CropGrowthStage.values[index],
                index: index + 1,
                active: index <= currentIndex,
                current: CropGrowthStage.values[index] == currentStage,
              ),
          ],
        );
      },
    );
  }
}

class _GrowthStageTile extends StatelessWidget {
  const _GrowthStageTile({
    required this.width,
    required this.stage,
    required this.index,
    required this.active,
    required this.current,
  });

  final double width;
  final CropGrowthStage stage;
  final int index;
  final bool active;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primaryGreen : AppColors.inactiveBorder;

    return SizedBox(
      width: width,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: current ? AppColors.cardBackground : AppColors.secondaryBackground,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: active ? color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: color),
                ),
                child: SizedBox.square(
                  dimension: 24,
                  child: Center(
                    child: Text(
                      '$index',
                      style: AppTypography.statusBadge.copyWith(
                        color: active
                            ? AppColors.primaryBackground
                            : AppColors.mutedText,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.small.copyWith(
                        color: active
                            ? AppColors.primaryText
                            : AppColors.mutedText,
                        fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      current ? 'Current' : active ? 'Done' : 'Pending',
                      style: AppTypography.statusBadge.copyWith(color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
