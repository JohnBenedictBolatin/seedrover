import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_page_header.dart';
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

class _NotificationListScreenState extends ConsumerState<NotificationListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (mounted && !_tabController.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationControllerProvider);
    final controller = ref.read(notificationControllerProvider.notifier);
    final isUnreadTab = _tabController.index == 0;
    final notifications = state.filteredNotifications
        .where((notification) => notification.isRead != isUnreadTab)
        .toList(growable: false);

    ref.listen(notificationControllerProvider, (previous, next) {
      final error = next.errorMessage;
      if (error != null &&
          error != previous?.errorMessage &&
          next.notifications.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        ref.read(notificationControllerProvider.notifier).clearErrorMessage();
        return;
      }
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

    if (state.errorMessage != null && state.notifications.isEmpty) {
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
          AppPageHeader(
              title: 'Notifications',
              actions: _UnreadCounter(count: state.unreadCount)),
          const SizedBox(height: AppSpacing.md),
          TabBar(
            controller: _tabController,
            isScrollable: false,
            tabAlignment: TabAlignment.fill,
            labelColor: AppColors.primaryGreen,
            unselectedLabelColor: AppColors.secondaryText,
            indicatorColor: AppColors.primaryGreen,
            labelStyle:
                AppTypography.small.copyWith(fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Unread'),
              Tab(text: 'Read'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          NotificationFilterBar(
            searchQuery: state.searchQuery,
            selectedCategory: state.selectedCategory,
            selectedPriority: state.selectedPriority,
            selectedDate: state.selectedDate,
            selectedSort: state.selectedSort,
            onSearchChanged: controller.updateSearch,
            onCategoryChanged: controller.updateCategory,
            onPriorityChanged: controller.updatePriority,
            onDateChanged: controller.updateDate,
            onSortChanged: controller.updateSort,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (notifications.isEmpty)
            NotificationEmptyState(
              hasNotifications: state.notifications.isNotEmpty,
              hasActiveFilters: state.searchQuery.trim().isNotEmpty ||
                  state.selectedCategory != null ||
                  state.selectedPriority != null ||
                  state.selectedDate != NotificationDateFilter.all,
              emptyTitle: state.notifications.isEmpty
                  ? 'No notifications yet'
                  : isUnreadTab
                      ? 'No unread notifications'
                      : 'No read notifications',
              emptyDescription: state.notifications.isEmpty
                  ? 'New updates will appear here.'
                  : isUnreadTab
                      ? 'You’re all caught up.'
                      : 'Read notifications will appear here.',
              onClearFilters: controller.clearFilters,
            )
          else
            _NotificationList(
              notifications: notifications,
              onView: (notification) async {
                if (context.mounted) {
                  context.push(controller.routeForNotification(notification));
                }
                if (!notification.isRead) {
                  try {
                    await controller.markAsRead(notification.id);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Couldn’t update read status.')),
                      );
                    }
                  }
                }
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
    DateTime? previousDate;
    final children = <Widget>[];

    for (var index = 0; index < notifications.length; index++) {
      final notification = notifications[index];
      final date = notification.createdAt.toLocal();
      if (previousDate == null || !DateUtils.isSameDay(previousDate, date)) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _dateGroupLabel(date),
                style: AppTypography.cardTitle.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ),
          ),
        );
        previousDate = date;
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

  String _dateGroupLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (DateUtils.isSameDay(date, today)) return 'Today';
    if (DateUtils.isSameDay(date, yesterday)) return 'Yesterday';
    return '${date.month}/${date.day}/${date.year}';
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
          style: AppTypography.numericCaption.copyWith(
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
