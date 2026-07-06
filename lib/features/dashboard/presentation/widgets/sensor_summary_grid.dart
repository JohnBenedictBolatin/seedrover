import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/dashboard_model.dart';
import 'dashboard_metric_tile.dart';

class SensorSummaryGrid extends StatelessWidget {
  const SensorSummaryGrid({
    required this.sensors,
    super.key,
  });

  final List<SensorSummaryModel> sensors;

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
            for (final sensor in sensors)
              SizedBox(
                width: tileWidth,
                child: DashboardMetricTile(
                  label: sensor.label,
                  value: '${sensor.value}${sensor.unit}',
                  caption: sensor.interpretation,
                  icon: _iconFor(sensor.label),
                  color: _colorFor(sensor.condition),
                  useMonoText: true,
                ),
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
      SensorCondition.excellent => AppColors.success,
      SensorCondition.moderate => AppColors.warning,
      SensorCondition.poor => AppColors.danger,
    };
  }
}
