import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/permission_keys.dart';
import '../../authentication/data/models/auth_profile_model.dart';
import '../data/models/notification_model.dart';
import '../data/repositories/notification_repository.dart';
import 'notification_state.dart';

class NotificationController extends StateNotifier<NotificationState> {
  NotificationController(this._repository, this._profile)
      : super(NotificationState.initial()) {
    unawaited(_loadInitialNotifications());
    _subscription = _repository.watchNotifications().listen(
      (notifications) => _setNotifications(
        notifications.where(_canViewNotification).toList(),
        successMessage: null,
        isLoading: false,
      ),
      onError: (_) {
        // Realtime can briefly fail while Supabase/Auth settles on startup.
        // The normal fetch path remains the source of truth for visible errors.
      },
    );
  }

  final NotificationRepository _repository;
  final AuthProfileModel? _profile;
  StreamSubscription<List<SeedRoverNotification>>? _subscription;

  Future<void> _loadInitialNotifications() async {
    await loadNotifications(retryAttempts: 2);
  }

  Future<void> loadNotifications({int retryAttempts = 0}) async {
    try {
      final notifications = (await _repository.getNotifications())
          .where(_canViewNotification)
          .toList();
      _setNotifications(
        notifications,
        successMessage: null,
        isLoading: false,
      );
    } catch (_) {
      if (retryAttempts > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 450));
        await loadNotifications(retryAttempts: retryAttempts - 1);
        return;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load notifications.',
      );
    }
  }

  Future<void> refreshNotifications() async {
    state = state.copyWith(isLoading: true, successMessage: null);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await loadNotifications();
  }

  SeedRoverNotification? notificationById(String notificationId) {
    for (final notification in state.notifications) {
      if (notification.id == notificationId) {
        return notification;
      }
    }

    return null;
  }

  String routeForNotification(SeedRoverNotification notification) {
    return notificationRouteFor(notification);
  }

  Future<void> markAsRead(String notificationId) async {
    await _repository.markAsRead(notificationId);
    _replaceNotification(
      notificationId,
      (notification) => notification.copyWith(isRead: true),
      successMessage: null,
    );
  }

  Future<void> markAsUnread(String notificationId) async {
    await _repository.markAsUnread(notificationId);
    _replaceNotification(
      notificationId,
      (notification) => notification.copyWith(isRead: false),
      successMessage: null,
    );
  }

  Future<void> toggleReadStatus(String notificationId) async {
    final notification = notificationById(notificationId);

    if (notification == null) {
      return;
    }

    if (notification.isRead) {
      await markAsUnread(notificationId);
      return;
    }

    await markAsRead(notificationId);
  }

  Future<void> deleteNotification(String notificationId) async {
    await _repository.deleteNotification(notificationId);
    final notifications = state.notifications
        .where((notification) => notification.id != notificationId)
        .toList();
    _setNotifications(
      notifications,
      successMessage: 'Notification deleted.',
      isLoading: false,
    );
  }

  void markAllAsRead() {
    final notifications = [
      for (final notification in state.notifications)
        notification.copyWith(isRead: true),
    ];
    _setNotifications(
      notifications,
      successMessage: 'All notifications marked as read.',
      isLoading: false,
    );
  }

  void deleteReadNotifications() {
    final notifications = state.notifications
        .where((notification) => !notification.isRead)
        .toList();
    _setNotifications(
      notifications,
      successMessage: 'Read notifications deleted.',
      isLoading: false,
    );
  }

  void clearAllNotifications() {
    _setNotifications(
      const [],
      successMessage: 'Notifications cleared.',
      isLoading: false,
    );
  }

  void updateSearch(String query) {
    _updateFilters(searchQuery: query);
  }

  void updateCategory(NotificationCategory? category) {
    _updateFilters(selectedCategory: category);
  }

  void updatePriority(NotificationPriority? priority) {
    _updateFilters(selectedPriority: priority);
  }

  void updateStatus(NotificationStatusFilter status) {
    _updateFilters(selectedStatus: status);
  }

  void updateDate(NotificationDateFilter date) {
    _updateFilters(selectedDate: date);
  }

  void updateSort(NotificationSortType sort) {
    _updateFilters(selectedSort: sort);
  }

  void clearFilters() {
    final filteredNotifications = _applyFilters(
      notifications: state.notifications,
      searchQuery: '',
      selectedCategory: null,
      selectedPriority: null,
      selectedStatus: NotificationStatusFilter.all,
      selectedDate: NotificationDateFilter.all,
      selectedSort: NotificationSortType.newest,
    );

    state = state.copyWith(
      searchQuery: '',
      selectedCategory: null,
      selectedPriority: null,
      selectedStatus: NotificationStatusFilter.all,
      selectedDate: NotificationDateFilter.all,
      selectedSort: NotificationSortType.newest,
      filteredNotifications: filteredNotifications,
      successMessage: null,
    );
  }

  void clearSuccessMessage() {
    state = state.copyWith(successMessage: null);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _replaceNotification(
    String notificationId,
    SeedRoverNotification Function(SeedRoverNotification notification) update, {
    required String? successMessage,
  }) {
    final notifications = [
      for (final notification in state.notifications)
        if (notification.id == notificationId)
          update(notification)
        else
          notification,
    ];
    _setNotifications(
      notifications,
      successMessage: successMessage,
      isLoading: false,
    );
  }

  void _updateFilters({
    String? searchQuery,
    Object? selectedCategory = _noCategoryChange,
    Object? selectedPriority = _noPriorityChange,
    NotificationStatusFilter? selectedStatus,
    NotificationDateFilter? selectedDate,
    NotificationSortType? selectedSort,
  }) {
    final nextSearchQuery = searchQuery ?? state.searchQuery;
    final nextCategory = selectedCategory == _noCategoryChange
        ? state.selectedCategory
        : selectedCategory as NotificationCategory?;
    final nextPriority = selectedPriority == _noPriorityChange
        ? state.selectedPriority
        : selectedPriority as NotificationPriority?;
    final nextStatus = selectedStatus ?? state.selectedStatus;
    final nextDate = selectedDate ?? state.selectedDate;
    final nextSort = selectedSort ?? state.selectedSort;
    final filteredNotifications = _applyFilters(
      notifications: state.notifications,
      searchQuery: nextSearchQuery,
      selectedCategory: nextCategory,
      selectedPriority: nextPriority,
      selectedStatus: nextStatus,
      selectedDate: nextDate,
      selectedSort: nextSort,
    );

    state = state.copyWith(
      searchQuery: nextSearchQuery,
      selectedCategory: nextCategory,
      selectedPriority: nextPriority,
      selectedStatus: nextStatus,
      selectedDate: nextDate,
      selectedSort: nextSort,
      filteredNotifications: filteredNotifications,
      successMessage: null,
    );
  }

  List<SeedRoverNotification> _applyFilters({
    required List<SeedRoverNotification> notifications,
    required String searchQuery,
    required NotificationCategory? selectedCategory,
    required NotificationPriority? selectedPriority,
    required NotificationStatusFilter selectedStatus,
    required NotificationDateFilter selectedDate,
    required NotificationSortType selectedSort,
  }) {
    final normalizedQuery = searchQuery.trim().toLowerCase();
    final now = DateTime.now();
    final filtered = notifications.where((notification) {
      final matchesSearch = normalizedQuery.isEmpty ||
          notification.title.toLowerCase().contains(normalizedQuery) ||
          notification.shortDescription
              .toLowerCase()
              .contains(normalizedQuery) ||
          notification.category.label.toLowerCase().contains(normalizedQuery);
      final matchesCategory = selectedCategory == null ||
          notification.category == selectedCategory;
      final matchesPriority = selectedPriority == null ||
          notification.priority == selectedPriority;
      final matchesStatus = switch (selectedStatus) {
        NotificationStatusFilter.all => true,
        NotificationStatusFilter.unread => !notification.isRead,
        NotificationStatusFilter.read => notification.isRead,
      };
      final matchesDate = _matchesDateFilter(
        notification.createdAt,
        selectedDate,
        now,
      );

      return matchesSearch &&
          matchesCategory &&
          matchesPriority &&
          matchesStatus &&
          matchesDate;
    }).toList();

    filtered.sort((left, right) {
      return switch (selectedSort) {
        NotificationSortType.newest => _compareUnreadPriorityFirst(
            left,
            right,
            compareDate: () => right.createdAt.compareTo(left.createdAt),
          ),
        NotificationSortType.oldest => _compareUnreadPriorityFirst(
            left,
            right,
            compareDate: () => left.createdAt.compareTo(right.createdAt),
          ),
        NotificationSortType.highestPriority =>
          _compareUnreadPriorityFirst(left, right),
        NotificationSortType.unreadFirst =>
          _compareUnreadPriorityFirst(left, right),
      };
    });

    return filtered;
  }

  bool _matchesDateFilter(
    DateTime date,
    NotificationDateFilter filter,
    DateTime now,
  ) {
    final todayStart = DateTime(now.year, now.month, now.day);
    final dateStart = DateTime(date.year, date.month, date.day);

    return switch (filter) {
      NotificationDateFilter.all => true,
      NotificationDateFilter.today => dateStart == todayStart,
      NotificationDateFilter.thisWeek =>
        date.isAfter(todayStart.subtract(const Duration(days: 7))),
      NotificationDateFilter.thisMonth =>
        date.year == now.year && date.month == now.month,
    };
  }

  int _compareUnreadPriorityFirst(
    SeedRoverNotification left,
    SeedRoverNotification right, {
    int Function()? compareDate,
  }) {
    if (left.isRead != right.isRead) {
      return left.isRead ? 1 : -1;
    }

    final priorityComparison = right.priority.rank.compareTo(left.priority.rank);
    if (priorityComparison != 0) {
      return priorityComparison;
    }

    return compareDate?.call() ?? right.createdAt.compareTo(left.createdAt);
  }

  void _setNotifications(
    List<SeedRoverNotification> notifications, {
    required String? successMessage,
    required bool isLoading,
  }) {
    final filteredNotifications = _applyFilters(
      notifications: notifications,
      searchQuery: state.searchQuery,
      selectedCategory: state.selectedCategory,
      selectedPriority: state.selectedPriority,
      selectedStatus: state.selectedStatus,
      selectedDate: state.selectedDate,
      selectedSort: state.selectedSort,
    );

    state = state.copyWith(
      notifications: notifications,
      filteredNotifications: filteredNotifications,
      isLoading: isLoading,
      successMessage: successMessage,
      errorMessage: null,
    );
  }

  bool _canViewNotification(SeedRoverNotification notification) {
    bool hasPermission(String permissionKey) {
      return _profile?.hasPermission(permissionKey) ?? false;
    }

    return switch (notification.relatedModule) {
      NotificationRelatedModule.inventory =>
        hasPermission(PermissionKeys.stocksView),
      NotificationRelatedModule.crops =>
        hasPermission(PermissionKeys.cropsView),
      NotificationRelatedModule.rover ||
      NotificationRelatedModule.camera =>
        hasPermission(PermissionKeys.roverView),
      NotificationRelatedModule.planting =>
        hasPermission(PermissionKeys.roverPlantingControl) ||
            hasPermission(PermissionKeys.cropsView),
      NotificationRelatedModule.users =>
        hasPermission(PermissionKeys.usersView),
      NotificationRelatedModule.dashboard =>
        hasPermission(PermissionKeys.dashboardView),
      NotificationRelatedModule.system =>
        hasPermission(PermissionKeys.notificationsView),
    };
  }
}

const _noCategoryChange = Object();
const _noPriorityChange = Object();
