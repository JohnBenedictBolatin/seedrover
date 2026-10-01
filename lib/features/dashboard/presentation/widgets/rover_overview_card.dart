import 'package:flutter/material.dart';

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
                      style: AppTypography.cardTitle,
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
          ),
          const SizedBox(height: AppSpacing.lg),
          ConnectionStatusRow(
            wifiConnected: rover.wifiConnected,
            bluetoothConnected: rover.bluetoothConnected,
            cameraConnected: rover.cameraConnected,
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedTypingText(
            'Planting Status: ${rover.plantingStatus}',
            style: AppTypography.small,
          ),
          const SizedBox(height: AppSpacing.xs),
          AnimatedTypingText(
            rover.lastCommunication == null
                ? 'Last communication: Not recorded'
                : 'Last communication: ${DateTimeFormatter.formatTime(rover.lastCommunication!)}',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}
