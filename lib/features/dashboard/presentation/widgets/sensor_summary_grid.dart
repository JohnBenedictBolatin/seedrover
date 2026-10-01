import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/dashboard_model.dart';
import 'dashboard_metric_tile.dart';

class SensorSummaryGrid extends StatefulWidget {
  const SensorSummaryGrid({
    required this.sensors,
    super.key,
  });

  final List<SensorSummaryModel> sensors;

  @override
  State<SensorSummaryGrid> createState() => _SensorSummaryGridState();
}

class _SensorSummaryGridState extends State<SensorSummaryGrid> {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        final spacing = AppSpacing.md * (columns - 1);
        final tileWidth = (constraints.maxWidth - spacing) / columns;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final sensor in widget.sensors)
              SizedBox(
                width: tileWidth,
                child: Builder(builder: (context) {
                  final age = sensor.recordedAt == null
                      ? null
                      : _now.difference(sensor.recordedAt!);
                  final timestampFresh = age != null &&
                      !age.isNegative &&
                      age <= const Duration(seconds: 60);
                  final valueAvailable = sensor.value != '?' &&
                      sensor.condition != SensorCondition.unavailable;
                  return DashboardMetricTile(
                    label: sensor.label,
                    value: timestampFresh && valueAvailable
                        ? '${sensor.value}${sensor.unit}'
                        : 'Unavailable',
                    caption: timestampFresh
                        ? sensor.interpretation
                        : 'Stale · no fresh verified reading',
                    icon: _iconFor(sensor.label),
                    color: timestampFresh && valueAvailable
                        ? _colorFor(sensor.condition)
                        : AppColors.mutedText,
                    useNumericTypography: true,
                  );
                }),
              ),
          ],
        );
      },
    );
  }

  IconData _iconFor(String label) {
    if (label.contains('Moisture')) {
      return CupertinoIcons.drop;
    }

    if (label.contains('Humidity')) {
      return CupertinoIcons.cloud;
    }

    if (label.contains('Air')) {
      return CupertinoIcons.sun_max;
    }

    return CupertinoIcons.thermometer;
  }

  Color _colorFor(SensorCondition condition) {
    return switch (condition) {
      SensorCondition.recorded => AppColors.secondaryText,
      SensorCondition.unavailable => AppColors.mutedText,
    };
  }
}
