import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/animated_content.dart';
import '../../data/models/notification_model.dart';
import '../../providers/notification_providers.dart';
import '../widgets/notification_card.dart';
import '../widgets/notification_empty_state.dart';
import '../widgets/notification_filter_bar.dart';
import '../widgets/notification_loading_list.dart';

class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationControllerProvider);
    final controller = ref.read(notificationControllerProvider.notifier);

    ref.listen(notificationControllerProvider, (previous, next) {
      final message = next.successMessage;

      if (message != null && message != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        ref.read(notificationControllerProvider.notifier).clearSuccessMessage();
      }
    });

    if (state.isLoading) {
      return const NotificationLoadingList();
    }

    if (state.errorMessage != null) {
      return _NotificationErrorState(
        message: state.errorMessage!,
        onRetry: controller.loadNotifications,
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refreshNotifications,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              Expanded(
                child: AnimatedTypingText(
                  'Notifications',
                  style: AppTypography.screenTitle.copyWith(
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              _UnreadCounter(count: state.unreadCount),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          NotificationFilterBar(
            searchQuery: state.searchQuery,
            selectedCategory: state.selectedCategory,
            selectedPriority: state.selectedPriority,
            selectedStatus: state.selectedStatus,
            onSearchChanged: controller.updateSearch,
            onCategoryChanged: controller.updateCategory,
            onPriorityChanged: controller.updatePriority,
            onStatusChanged: controller.updateStatus,
            onClear: controller.clearFilters,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (state.filteredNotifications.isEmpty)
            const NotificationEmptyState()
          else
            _NotificationList(
              notifications: state.filteredNotifications,
              onView: (notification) {
                controller.markAsRead(notification.id);
                context.push(controller.routeForNotification(notification));
              },
            ),
        ],
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList({
    required this.notifications,
    required this.onView,
  });

  final List<SeedRoverNotification> notifications;
  final ValueChanged<SeedRoverNotification> onView;

  @override
  Widget build(BuildContext context) {
    var readDividerShown = false;
    final children = <Widget>[];

    for (var index = 0; index < notifications.length; index++) {
      final notification = notifications[index];

      if (notification.isRead && !readDividerShown) {
        children.add(const _AlreadyReadDivider());
        children.add(const SizedBox(height: AppSpacing.md));
        readDividerShown = true;
      }

      children.add(
        NotificationCard(
          notification: notification,
          onView: () => onView(notification),
        ),
      );

      if (index != notifications.length - 1) {
        children.add(const SizedBox(height: AppSpacing.md));
      }
    }

    return Column(
      children: children,
    );
  }
}

class _AlreadyReadDivider extends StatelessWidget {
  const _AlreadyReadDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: AppColors.inactiveBorder, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            'Already read',
            style: AppTypography.statusBadge.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: AppColors.inactiveBorder, thickness: 1),
        ),
      ],
    );
  }
}

class _UnreadCounter extends StatelessWidget {
  const _UnreadCounter({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border.all(color: AppColors.primaryText),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          '$count unread',
          style: AppTypography.statusBadge.copyWith(
            color: AppColors.primaryText,
          ),
        ),
      ),
    );
  }
}

class _NotificationErrorState extends StatelessWidget {
  const _NotificationErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: AppColors.warning,
              size: 42,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
