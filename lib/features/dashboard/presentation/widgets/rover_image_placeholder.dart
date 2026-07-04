import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/status_badge.dart';

class RoverImagePlaceholder extends StatelessWidget {
  const RoverImagePlaceholder({
    required this.isInUse,
    required this.usageDuration,
    super.key,
  });

  final bool isInUse;
  final Duration usageDuration;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.inactiveBorder),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Stack(
            children: [
              const Center(
                child: Icon(
                  CupertinoIcons.car_detailed,
                  color: AppColors.mutedText,
                  size: 56,
                ),
              ),
              Align(
                alignment: Alignment.topLeft,
                child: StatusBadge(
                  label: isInUse ? 'IN USE' : 'IDLE',
                  color: isInUse ? AppColors.primaryGreen : AppColors.mutedText,
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rover Image', style: AppTypography.small),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Runtime: ${_formatDuration(usageDuration)}',
                      style: AppTypography.sensorValue.copyWith(
                        color: AppColors.primaryGreen,
                      ),
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

  String _formatDuration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);

    if (hours == 0) {
      return '${minutes}m';
    }

    return '${hours}h ${minutes}m';
  }
}
