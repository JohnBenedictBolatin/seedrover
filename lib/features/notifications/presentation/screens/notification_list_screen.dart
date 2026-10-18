import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../../shared/widgets/action_result_dialog.dart';
import '../../../../shared/widgets/initial_loading_skeleton.dart';
import '../../../../shared/widgets/floating_app_notice.dart';
import '../../data/models/notification_model.dart';
import '../../providers/notification_providers.dart';
import '../widgets/notification_card.dart';
import '../widgets/notification_empty_state.dart';
import '../widgets/notification_filter_bar.dart';
import '../widgets/notification_loading_list.dart';

class NotificationListScreen extends ConsumerStatefulWidget {
  const NotificationListScreen({super.key});

  @override
  ConsumerState<NotificationListScreen> createState() =>
      _NotificationListScreenState();
}

class _NotificationListScreenState
    extends ConsumerState<NotificationListScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationControllerProvider);
    final controller = ref.read(notificationControllerProvider.notifier);
    final notifications = state.filteredNotifications;
    final newestNotificationId =
        notifications.isEmpty ? null : notifications.first.id;

    ref.listen(notificationControllerProvider, (previous, next) {
      final error = next.errorMessage;
      if (error != null &&
          error != previous?.errorMessage &&
          next.notifications.isNotEmpty &&
          error != 'Unable to load notifications.') {
        showActionResult(context, message: error, success: false);
        ref.read(notificationControllerProvider.notifier).clearErrorMessage();
        return;
      }
      final message = next.successMessage;

      if (message != null && message != previous?.successMessage) {
        showActionResult(context, message: message);
        ref.read(notificationControllerProvider.notifier).clearSuccessMessage();
      }
    });

    if (state.isLoading && !state.hasLoaded) {
      return const InitialLoadingSkeleton(
        skeleton: NotificationLoadingList(),
        label: 'Loading notifications…',
      );
    }

    if (state.errorMessage != null &&
        state.notifications.isEmpty &&
        !state.hasLoaded) {
      return _NotificationErrorState(
        message: state.errorMessage!,
        onRetry: controller.loadNotifications,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        RefreshIndicator(
          onRefresh: controller.refreshNotifications,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppPageHeader(title: 'Notifications'),
              const SizedBox(height: AppSpacing.md),
              NotificationFilterBar(
                searchQuery: state.searchQuery,
                selectedCategory: state.selectedCategory,
                selectedStatus: state.selectedStatus,
                selectedDate: state.selectedDate,
                onSearchChanged: controller.updateSearch,
                onCategoryChanged: controller.updateCategory,
                onStatusChanged: controller.updateStatus,
                onDateChanged: controller.updateDate,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (notifications.isEmpty)
                NotificationEmptyState(
                  hasNotifications: state.notifications.isNotEmpty,
                  hasActiveFilters: state.searchQuery.trim().isNotEmpty ||
                      state.selectedCategory != null ||
                      state.selectedStatus != NotificationStatusFilter.all ||
                      state.selectedDate != NotificationDateFilter.all,
                  emptyTitle: state.notifications.isEmpty
                      ? 'No notifications yet'
                      : 'No matching notifications',
                  emptyDescription: state.notifications.isEmpty
                      ? 'New updates will appear here.'
                      : 'Try changing your search or filters.',
                  onClearFilters: controller.clearFilters,
                )
              else
                _NotificationList(
                  notifications: notifications,
                  newestNotificationId: newestNotificationId,
                  onView: (notification) async {
                    if (context.mounted) {
                      context
                          .push(controller.routeForNotification(notification));
                    }
                    if (!notification.isRead) {
                      try {
                        await controller.markAsRead(notification.id);
                      } catch (_) {
                        if (context.mounted) {
                          showActionResult(context,
                              message: 'Could not update read status.',
                              success: false);
                        }
                      }
                    }
                  },
                ),
            ],
          ),
        ),
        if (state.errorMessage != null)
          Positioned(
            right: 12,
            bottom: 12,
            width: (MediaQuery.sizeOf(context).width - 24)
                .clamp(0.0, 420.0)
                .toDouble(),
            child: FloatingAppNotice(
              title: 'Could not refresh notifications',
              message: state.errorMessage!,
              tone: FloatingNoticeTone.warning,
              icon: Icons.cloud_off_outlined,
              onRetry: controller.loadNotifications,
              onDismiss: controller.clearErrorMessage,
            ),
          ),
      ],
    );
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList({
    required this.notifications,
    required this.newestNotificationId,
    required this.onView,
  });

  final List<SeedRoverNotification> notifications;
  final String? newestNotificationId;
  final ValueChanged<SeedRoverNotification> onView;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    for (var index = 0; index < notifications.length; index++) {
      final notification = notifications[index];
      final isNewest = notification.id == newestNotificationId;
      final startsOlderGroup = !isNewest &&
          (index == 0 || notifications[index - 1].id == newestNotificationId);
      if (isNewest || startsOlderGroup) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isNewest ? 'Newest' : 'Older',
                style: AppTypography.cardTitle.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ),
          ),
        );
      }

      children.add(
        NotificationCard(
          notification: notification,
          isUnread: !notification.isRead,
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
            Icon(
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
