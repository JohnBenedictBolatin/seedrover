import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/soil_moisture_reference_label.dart';
import '../../../../shared/utils/sensor_reading_age_label.dart';
import '../../data/models/crop_model.dart';

class CropSensorSnapshotGrid extends StatefulWidget {
  const CropSensorSnapshotGrid({
    required this.snapshot,
    super.key,
  });

  final CropSensorSnapshot snapshot;

  @override
  State<CropSensorSnapshotGrid> createState() => _CropSensorSnapshotGridState();
}

class _CropSensorSnapshotGridState extends State<CropSensorSnapshotGrid> {
  Timer? _freshnessTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _freshnessTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _freshnessTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final age = snapshot.recordedAt == null
        ? null
        : _now.difference(snapshot.recordedAt!);
    final fresh =
        age != null && !age.isNegative && age <= const Duration(seconds: 60);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        snapshot.recordedAt == null
            ? 'No reading recorded'
            : '${snapshot.source ?? "Verified hardware"} · ${sensorReadingAgeLabel(snapshot.recordedAt, now: _now)}',
        style: AppTypography.caption.copyWith(color: AppColors.secondaryText),
      ),
      if (!fresh)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            'Sensor values are shown only for readings from the last minute.',
            style: AppTypography.caption.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ),
      const SizedBox(height: AppSpacing.md),
      Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          _SensorTile(
              label: 'Soil Moisture',
              value: _reading(fresh ? snapshot.soilMoisture : null, '%'),
              detail: fresh && snapshot.soilMoistureCalibrated == true
                  ? soilMoistureReferenceLabel(snapshot.soilMoisture)
                  : null),
          _SensorTile(
              label: 'Raw soil probe (ADC)',
              value: fresh
                  ? snapshot.soilRaw?.toString() ?? 'Not available'
                  : 'Not available'),
          _SensorTile(
              label: 'Soil Temp',
              value: _reading(fresh ? snapshot.soilTemperature : null, '°C')),
          _SensorTile(
            label: 'Env Temp',
            value:
                _reading(fresh ? snapshot.environmentTemperature : null, '°C'),
          ),
          _SensorTile(
              label: 'Humidity',
              value: _reading(fresh ? snapshot.humidity : null, '%')),
        ],
      ),
    ]);
  }
}

String _reading(double? value, String unit) =>
    value == null ? 'Not available' : '${value.toStringAsFixed(1)}$unit';

class _SensorTile extends StatelessWidget {
  const _SensorTile({
    required this.label,
    required this.value,
    this.detail,
  });

  final String label;
  final String value;
  final String? detail;

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
              Text(label, style: AppTypography.caption),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: AppTypography.numericValue.copyWith(
                  color: AppColors.primaryGreen,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  detail!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
