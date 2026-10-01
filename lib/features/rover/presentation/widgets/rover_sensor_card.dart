import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/soil_moisture_reference_label.dart';
import '../../../../shared/utils/sensor_reading_age_label.dart';
import '../../../../shared/widgets/animated_content.dart';
import '../../data/models/rover_control_model.dart';

class RoverSensorCard extends StatefulWidget {
  const RoverSensorCard({
    required this.sensor,
    required this.icon,
    required this.gradientColors,
    super.key,
    this.compact = false,
  });

  final RoverSensorModel sensor;
  final IconData icon;
  final List<Color> gradientColors;
  final bool compact;

  @override
  State<RoverSensorCard> createState() => _RoverSensorCardState();
}

class _RoverSensorCardState extends State<RoverSensorCard> {
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
    final sensor = widget.sensor;
    final textScaler = MediaQuery.textScalerOf(context);
    // Keep the last real value visible when it ages out. Freshness is shown
    // separately so a useful reading does not disappear after one minute.
    final value = sensor.value;
    final interpretation = value == null ? '' : _interpretationLabel();
    final displayValue = value == null
        ? 'Not available'
        : '${value.toStringAsFixed(_usesFractionalPrecision(sensor) ? 1 : 0)}${sensor.unit}';

    if (widget.compact) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.gradientColors,
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(widget.icon, color: Colors.white, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                  child: AnimatedTypingText(_shortLabel(sensor.label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ))),
              const SizedBox(width: AppSpacing.xs),
              AnimatedMetricText(
                  displayValue,
                  style: AppTypography.numericValue.copyWith(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  )),
            ]),
            if (interpretation.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 3),
                child: Text(
                  interpretation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: Colors.white.withValues(alpha: .88),
                    fontSize: 10,
                  ),
                ),
              ),
          ]),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.gradientColors,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? AppSpacing.sm : AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(widget.icon,
                color: Colors.white, size: widget.compact ? 18 : 24),
            SizedBox(height: widget.compact ? AppSpacing.xs : AppSpacing.md),
            AnimatedTypingText(
              sensor.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.small.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: textScaler.scale(24) * 1.2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: value == null
                    ? Text(
                        'Not available',
                        style: AppTypography.small.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : AnimatedMetricText(
                        displayValue,
                        style: AppTypography.numericValue.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: textScaler.scale(12) * 1.25 * 2,
              child: interpretation.isEmpty
                  ? null
                  : AnimatedTypingText(
                      interpretation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: Colors.white.withValues(alpha: .88),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortLabel(String label) {
    return switch (label) {
      'Soil Moisture' => 'Soil H2O',
      'Soil Temperature' => 'Soil Temp',
      'Air Temperature' => 'Air Temp',
      'Environmental Temperature' => 'Env Temp',
      _ => label,
    };
  }

  String _interpretationLabel() {
    final sensor = widget.sensor;
    final recordedAt = sensor.recordedAt;
    if (recordedAt != null) {
      final age = _now.difference(recordedAt);
      if (!age.isNegative && age > const Duration(seconds: 60)) {
        return sensorReadingAgeLabel(recordedAt, now: _now);
      }
    }
    if (sensor.label.toLowerCase().contains('moisture') &&
        sensor.soilMoistureCalibrated == true) {
      final quality = sensor.status.replaceFirst('Relative range · ', '');
      return '${soilMoistureReferenceLabel(sensor.value)} · $quality';
    }
    final status = sensor.status.trim();
    if (status.isEmpty || status.toLowerCase().contains('unavailable')) {
      return '';
    }
    return status;
  }

  bool _usesFractionalPrecision(RoverSensorModel sensor) =>
      sensor.label.toLowerCase().contains('moisture');

}
