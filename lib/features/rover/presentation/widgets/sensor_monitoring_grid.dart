import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/rover_control_model.dart';
import 'rover_sensor_card.dart';

class SensorMonitoringGrid extends StatelessWidget {
  const SensorMonitoringGrid({
    required this.sensors,
    super.key,
    this.compact = false,
  });

  final List<RoverSensorModel> sensors;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return GridView.count(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 3.35,
        children: [
          for (final sensor in sensors)
            RoverSensorCard(
              sensor: sensor,
              icon: _iconFor(sensor.label),
              color: _colorFor(sensor.status),
              compact: true,
            ),
        ],
      );
    }

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
                child: RoverSensorCard(
                  sensor: sensor,
                  icon: _iconFor(sensor.label),
                  color: _colorFor(sensor.status),
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

    if (label.contains('Environmental')) {
      return CupertinoIcons.sun_max;
    }

    return CupertinoIcons.thermometer;
  }

  Color _colorFor(String status) {
    return switch (status) {
      'Good' => AppColors.success,
      'Moderate' => AppColors.warning,
      _ => AppColors.danger,
    };
  }
}
