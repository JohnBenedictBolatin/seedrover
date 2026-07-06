import 'package:flutter/cupertino.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../data/models/dashboard_model.dart';

class RecentActivityPanel extends StatelessWidget {
  const RecentActivityPanel({
    required this.activities,
    super.key,
  });

  final List<ActivityPreviewModel> activities;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final activity in activities) ...[
          _RecentActivityTile(activity: activity),
          if (activity != activities.last)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _RecentActivityTile extends StatelessWidget {
  const _RecentActivityTile({required this.activity});

  final ActivityPreviewModel activity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.inactiveBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              CupertinoIcons.clock,
              color: AppColors.primaryGreen,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(activity.title, style: AppTypography.cardTitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(activity.description, style: AppTypography.small),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${activity.module} - '
                    '${DateTimeFormatter.formatTime(activity.timestamp)}',
                    style: AppTypography.monoCaption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
