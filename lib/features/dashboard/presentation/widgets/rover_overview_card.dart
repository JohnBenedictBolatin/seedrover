import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../../../shared/widgets/animated_content.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/models/dashboard_model.dart';
import 'connection_status_row.dart';
import 'rover_image_placeholder.dart';

class RoverOverviewCard extends StatelessWidget {
  const RoverOverviewCard({
    required this.rover,
    super.key,
  });

  final RoverOverviewModel rover;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedTypingText(
                      rover.unitName,
                      style: AppTypography.monoCardTitle,
                    ),
                  ],
                ),
              ),
              StatusBadge(label: rover.status),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          RoverImagePlaceholder(
            isInUse: rover.isInUse,
            usageDuration: rover.usageDuration,
          ),
          const SizedBox(height: AppSpacing.lg),
          ConnectionStatusRow(
            wifiConnected: rover.wifiConnected,
            bluetoothConnected: rover.bluetoothConnected,
            cameraConnected: rover.cameraConnected,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _InlineMetric(
                  label: 'Battery',
                  value: '${rover.batteryLevel}%',
                  icon: CupertinoIcons.battery_100,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _InlineMetric(
                  label: 'Seed Level',
                  value: '${rover.seedLevel}%',
                  icon: CupertinoIcons.circle_grid_hex,
                  color: AppColors.accentGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedTypingText(
            'Planting Status: ${rover.plantingStatus}',
            style: AppTypography.small,
          ),
          const SizedBox(height: AppSpacing.xs),
          AnimatedTypingText(
            'Last communication: '
            '${DateTimeFormatter.formatTime(rover.lastCommunication)}',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedTypingText(label, style: AppTypography.caption),
              AnimatedMetricText(
                value,
                style: AppTypography.sensorValue.copyWith(color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
