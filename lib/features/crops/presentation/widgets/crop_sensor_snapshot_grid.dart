import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/animated_content.dart';
import '../../data/models/crop_model.dart';

class CropSensorSnapshotGrid extends StatelessWidget {
  const CropSensorSnapshotGrid({
    required this.snapshot,
    super.key,
  });

  final CropSensorSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        _SensorTile(label: 'Soil Moisture', value: '${snapshot.soilMoisture}%'),
        _SensorTile(label: 'Soil Temp', value: '${snapshot.soilTemperature}C'),
        _SensorTile(
          label: 'Env Temp',
          value: '${snapshot.environmentTemperature}C',
        ),
        _SensorTile(label: 'Humidity', value: '${snapshot.humidity}%'),
      ],
    );
  }
}

class _SensorTile extends StatelessWidget {
  const _SensorTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          border: Border.all(color: AppColors.inactiveBorder),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedTypingText(label, style: AppTypography.caption),
              const SizedBox(height: AppSpacing.xs),
              AnimatedMetricText(
                value,
                style: AppTypography.sensorValue.copyWith(
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
