import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/rover_control_model.dart';

class RoverSensorCard extends StatelessWidget {
  const RoverSensorCard({
    required this.sensor,
    required this.icon,
    required this.color,
    super.key,
    this.compact = false,
  });

  final RoverSensorModel sensor;
  final IconData icon;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.inactiveBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _shortLabel(sensor.label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: sensor.value),
                duration: const Duration(milliseconds: 350),
                builder: (context, value, child) {
                  return Text(
                    '${value.toStringAsFixed(0)}${sensor.unit}',
                    style: AppTypography.sensorValue.copyWith(
                      color: color,
                      fontSize: 15,
                      height: 1,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.inactiveBorder),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: compact ? 18 : 24),
            SizedBox(height: compact ? AppSpacing.xs : AppSpacing.md),
            Text(
              sensor.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.small,
            ),
            const SizedBox(height: AppSpacing.xs),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: sensor.value),
              duration: const Duration(milliseconds: 350),
              builder: (context, value, child) {
                return Text(
                  '${value.toStringAsFixed(0)}${sensor.unit}',
                  style: AppTypography.sensorValue.copyWith(color: color),
                );
              },
            ),
            if (!compact) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(sensor.status, style: AppTypography.caption),
            ],
          ],
        ),
      ),
    );
  }

  String _shortLabel(String label) {
    return switch (label) {
      'Soil Moisture' => 'Soil H2O',
      'Soil Temperature' => 'Soil Temp',
      'Environmental Temperature' => 'Env Temp',
      _ => label,
    };
  }
}
