import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/utils/sensor_reading_age_label.dart';

class CropDetailMetric extends StatefulWidget {
  const CropDetailMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.width = 190,
    this.detail,
    this.freshnessTimestamp,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final double width;
  final String? detail;
  final DateTime? freshnessTimestamp;

  @override
  State<CropDetailMetric> createState() => _CropDetailMetricState();
}

class _CropDetailMetricState extends State<CropDetailMetric> {
  Timer? _freshnessTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.freshnessTimestamp != null) {
      _freshnessTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _freshnessTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = widget.freshnessTimestamp;
    final age = timestamp == null ? null : _now.difference(timestamp);
    final fresh = timestamp == null ||
        (age != null && !age.isNegative && age <= const Duration(seconds: 60));
    return SizedBox(
      width: widget.width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.icon, color: AppColors.primaryGreen, size: 14),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: AppTypography.caption,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                fresh ? widget.value : 'Unavailable',
                style: AppTypography.numericSmall,
              ),
              if (widget.detail != null || !fresh) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                    !fresh
                        ? sensorReadingAgeLabel(timestamp, now: _now)
                        : widget.detail ?? '',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.secondaryText)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
