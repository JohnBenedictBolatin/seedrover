import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../providers/notification_providers.dart';
import '../widgets/notification_card.dart';

class NotificationDetailsScreen extends ConsumerWidget {
  const NotificationDetailsScreen({
    required this.notificationId,
    super.key,
  });

  final String notificationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(notificationControllerProvider.notifier);
    final notification = controller.notificationById(notificationId);
    final actionRoute = notification == null
        ? null
        : controller.routeForNotification(notification);
    final currentDetailsRoute = AppRoutes.notificationDetailsPath(
      notificationId,
    );
    final resolvedActionRoute = actionRoute ?? '';
    final hasExternalAction = resolvedActionRoute.isNotEmpty &&
        resolvedActionRoute != currentDetailsRoute;

    if (notification == null) {
      return Center(
        child: Text('Notification not found.', style: AppTypography.body),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                  return;
                }

                context.go(AppRoutes.notifications);
              },
              icon: const Icon(
                CupertinoIcons.arrow_left,
                color: AppColors.primaryGreen,
              ),
            ),
            Expanded(
              child: Text(
                'Notification Details',
                style: AppTypography.sectionHeading.copyWith(
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          backgroundColor: AppColors.secondaryBackground,
          borderColor: AppColors.inactiveBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    notificationCategoryIcon(notification.category),
                    color: AppColors.primaryGreen,
                    size: 26,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      notification.title,
                      style: AppTypography.sectionHeading,
                    ),
                  ),
                  StatusBadge(
                    label: notification.priority.label,
                    color: notificationPriorityColor(notification.priority),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(notification.fullDescription, style: AppTypography.body),
              const SizedBox(height: AppSpacing.lg),
              _DetailGrid(notificationId: notificationId),
              const SizedBox(height: AppSpacing.lg),
              if (hasExternalAction)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      controller.markAsRead(notification.id);
                      context.push(resolvedActionRoute);
                    },
                    icon: const Icon(
                      CupertinoIcons.arrow_right_circle,
                      color: AppColors.primaryGreen,
                    ),
                    label: Text('Open ${notification.relatedModule.label}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(color: AppColors.primaryGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailGrid extends ConsumerWidget {
  const _DetailGrid({required this.notificationId});

  final String notificationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notification = ref
        .read(notificationControllerProvider.notifier)
        .notificationById(notificationId);

    if (notification == null) {
      return const SizedBox.shrink();
    }

    final details = [
      ('Category', notification.category.label),
      ('Priority', notification.priority.label),
      ('Date', _formatDate(notification.createdAt)),
      ('Time', _formatTime(notification.createdAt)),
      ('Triggered By', notification.triggeredBy),
      ('Related Module', notification.relatedModule.label),
      ('Related Item', notification.relatedItem ?? 'None'),
      ('Status', notification.isRead ? 'Read' : 'Unread'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 2;
        final spacing = AppSpacing.xs * (columns - 1);
        final width = (constraints.maxWidth - spacing) / columns;

        return Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final detail in details)
              SizedBox(
                width: width,
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
                        Text(detail.$1, style: AppTypography.caption),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          detail.$2,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.small.copyWith(
                            color: AppColors.primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year.toString().substring(2)}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12
        ? date.hour - 12
        : date.hour == 0
            ? 12
            : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $suffix';
  }
}
