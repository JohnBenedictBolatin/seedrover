import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/animated_content.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/models/notification_model.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    required this.notification,
    required this.onView,
    super.key,
  });

  final SeedRoverNotification notification;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final priorityColor = notificationPriorityColor(notification.priority);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onView,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: notification.isRead
              ? AppColors.secondaryBackground
              : AppColors.cardBackground,
          border: Border.all(
            color: notification.priority == NotificationPriority.critical
                ? AppColors.danger
                : AppColors.inactiveBorder,
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NotificationIcon(category: notification.category),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedTypingText(
                      notification.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle.copyWith(
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AnimatedTypingText(
                      notification.shortDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        StatusBadge(
                          label: notification.priority.label,
                          color: priorityColor,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AnimatedTypingText(
                            _formatTimestamp(notification.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.monoCaption,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ReadDot(isRead: notification.isRead),
                  const SizedBox(height: AppSpacing.xl),
                  const SizedBox(height: AppSpacing.md),
                  const Icon(
                    CupertinoIcons.arrow_right,
                    color: AppColors.primaryText,
                    size: 23,
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

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({required this.category});

  final NotificationCategory category;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Icon(
            notificationCategoryIcon(category),
            color: AppColors.primaryGreen,
            size: 23,
          ),
        ),
      ),
    );
  }
}

class _ReadDot extends StatelessWidget {
  const _ReadDot({required this.isRead});

  final bool isRead;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isRead ? AppColors.mutedText : AppColors.primaryGreen,
        shape: BoxShape.circle,
      ),
      child: const SizedBox.square(dimension: 9),
    );
  }
}

IconData notificationCategoryIcon(NotificationCategory category) {
  return switch (category) {
    NotificationCategory.system => CupertinoIcons.gear,
    NotificationCategory.robot => Icons.tire_repair_outlined,
    NotificationCategory.planting => Icons.grass_outlined,
    NotificationCategory.cropMonitoring => Icons.spa_outlined,
    NotificationCategory.inventory => CupertinoIcons.cube_box,
    NotificationCategory.battery => CupertinoIcons.battery_25,
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
