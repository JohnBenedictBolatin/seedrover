import '../data/models/notification_model.dart';

class NotificationState {
  const NotificationState({
    required this.notifications,
    required this.filteredNotifications,
    required this.searchQuery,
    required this.selectedCategory,
    required this.selectedPriority,
    required this.selectedStatus,
    required this.selectedDate,
    required this.selectedSort,
    required this.isLoading,
    required this.successMessage,
    required this.errorMessage,
  });

  factory NotificationState.initial() {
    return const NotificationState(
      notifications: [],
      filteredNotifications: [],
      searchQuery: '',
      selectedCategory: null,
      selectedPriority: null,
      selectedStatus: NotificationStatusFilter.all,
      selectedDate: NotificationDateFilter.all,
      selectedSort: NotificationSortType.newest,
      isLoading: true,
      successMessage: null,
      errorMessage: null,
    );
  }

  final List<SeedRoverNotification> notifications;
  final List<SeedRoverNotification> filteredNotifications;
  final String searchQuery;
  final NotificationCategory? selectedCategory;
  final NotificationPriority? selectedPriority;
  final NotificationStatusFilter selectedStatus;
  final NotificationDateFilter selectedDate;
  final NotificationSortType selectedSort;
  final bool isLoading;
  final String? successMessage;
  final String? errorMessage;

  int get unreadCount {
    return notifications.where((notification) => !notification.isRead).length;
  }

  NotificationState copyWith({
    List<SeedRoverNotification>? notifications,
    List<SeedRoverNotification>? filteredNotifications,
    String? searchQuery,
    Object? selectedCategory = _noChange,
    Object? selectedPriority = _noChange,
    NotificationStatusFilter? selectedStatus,
    NotificationDateFilter? selectedDate,
    NotificationSortType? selectedSort,
    bool? isLoading,
    Object? successMessage = _noChange,
    Object? errorMessage = _noChange,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      filteredNotifications:
          filteredNotifications ?? this.filteredNotifications,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory == _noChange
          ? this.selectedCategory
          : selectedCategory as NotificationCategory?,
      selectedPriority: selectedPriority == _noChange
          ? this.selectedPriority
          : selectedPriority as NotificationPriority?,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedSort: selectedSort ?? this.selectedSort,
      isLoading: isLoading ?? this.isLoading,
      successMessage: successMessage == _noChange
          ? this.successMessage
          : successMessage as String?,
      errorMessage: errorMessage == _noChange
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const _noChange = Object();
