import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/animated_content.dart';
import '../../data/models/notification_model.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    required this.notification,
    required this.isUnread,
    required this.onView,
    super.key,
  });

  final SeedRoverNotification notification;
  final bool isUnread;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final isImportant = notification.priority == NotificationPriority.high ||
        notification.priority == NotificationPriority.critical;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onView,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isUnread
              ? AppColors.sageSurface
              : AppColors.secondaryBackground,
          border: Border.all(
            color: isUnread
                ? AppColors.primaryGreen.withValues(alpha: 0.28)
                : AppColors.inactiveBorder,
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AnimatedTypingText(
                      notification.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle.copyWith(
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                  if (isImportant) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Tooltip(
                      message: 'Important notification',
                      child: Icon(
                        Icons.warning_rounded,
                        color: AppColors.danger,
                        size: 20,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              AnimatedTypingText(
                notification.shortDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: notification.actorName == null
                        ? const SizedBox.shrink()
                        : Text(
                            'By ${notification.actorName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.numericCaption.copyWith(
                              color: AppColors.mutedText,
                            ),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _formatTimestamp(notification.createdAt),
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.numericCaption,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final hour = timestamp.hour > 12
        ? timestamp.hour - 12
        : timestamp.hour == 0
            ? 12
            : timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final suffix = timestamp.hour >= 12 ? 'PM' : 'AM';

    return '${timestamp.month}/${timestamp.day}/${timestamp.year.toString().substring(2)} $hour:$minute $suffix';
  }
}

IconData notificationCategoryIcon(NotificationCategory category) {
  return switch (category) {
    NotificationCategory.system => CupertinoIcons.gear,
    NotificationCategory.robot => Icons.tire_repair_outlined,
    NotificationCategory.planting => Icons.grass_outlined,
    NotificationCategory.cropMonitoring => Icons.spa_outlined,
    NotificationCategory.inventory => CupertinoIcons.cube_box,
    NotificationCategory.camera => CupertinoIcons.camera,
    NotificationCategory.userManagement => CupertinoIcons.person_2,
  };
}

Color notificationPriorityColor(NotificationPriority priority) {
  return switch (priority) {
    NotificationPriority.critical => AppColors.danger,
    NotificationPriority.high => AppColors.warning,
    NotificationPriority.medium => AppColors.information,
    NotificationPriority.low => AppColors.primaryGreen,
  };
}
