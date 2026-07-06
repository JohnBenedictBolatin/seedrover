import '../../../../core/constants/app_routes.dart';

enum NotificationCategory {
  system,
  robot,
  planting,
  cropMonitoring,
  inventory,
  battery,
  camera,
  userManagement;

  String get label {
    return switch (this) {
      NotificationCategory.system => 'System',
      NotificationCategory.robot => 'Robot',
      NotificationCategory.planting => 'Planting',
      NotificationCategory.cropMonitoring => 'Crop Monitoring',
      NotificationCategory.inventory => 'Inventory',
      NotificationCategory.battery => 'Battery',
      NotificationCategory.camera => 'Camera',
      NotificationCategory.userManagement => 'User Management',
    };
  }
}

enum NotificationPriority {
  critical,
  high,
  medium,
  low;

  String get label {
    return switch (this) {
      NotificationPriority.critical => 'Critical',
      NotificationPriority.high => 'High',
      NotificationPriority.medium => 'Medium',
      NotificationPriority.low => 'Low',
    };
  }

  int get rank {
    return switch (this) {
      NotificationPriority.critical => 4,
      NotificationPriority.high => 3,
      NotificationPriority.medium => 2,
      NotificationPriority.low => 1,
    };
  }
}

enum NotificationRelatedModule {
  dashboard,
  rover,
  camera,
  planting,
  crops,
  inventory,
  users,
  system;

  String get label {
    return switch (this) {
      NotificationRelatedModule.dashboard => 'Dashboard',
      NotificationRelatedModule.rover => 'Rover Control',
      NotificationRelatedModule.camera => 'Live Camera',
      NotificationRelatedModule.planting => 'Planting Log',
      NotificationRelatedModule.crops => 'Crop Monitoring',
      NotificationRelatedModule.inventory => 'Inventory',
      NotificationRelatedModule.users => 'User Management',
      NotificationRelatedModule.system => 'System',
    };
  }
}

enum NotificationStatusFilter {
  all,
  unread,
  read;

  String get label {
    return switch (this) {
      NotificationStatusFilter.all => 'All',
      NotificationStatusFilter.unread => 'Unread',
      NotificationStatusFilter.read => 'Read',
    };
  }
}

enum NotificationDateFilter {
  all,
  today,
  thisWeek,
  thisMonth;

  String get label {
    return switch (this) {
      NotificationDateFilter.all => 'All Dates',
      NotificationDateFilter.today => 'Today',
      NotificationDateFilter.thisWeek => 'This Week',
      NotificationDateFilter.thisMonth => 'This Month',
    };
  }
}

enum NotificationSortType {
  newest,
  oldest,
  highestPriority,
  unreadFirst;

  String get label {
    return switch (this) {
      NotificationSortType.newest => 'Newest',
      NotificationSortType.oldest => 'Oldest',
      NotificationSortType.highestPriority => 'Priority',
      NotificationSortType.unreadFirst => 'Unread',
    };
  }
}

class SeedRoverNotification {
  const SeedRoverNotification({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.fullDescription,
    required this.category,
    required this.priority,
    required this.createdAt,
    required this.triggeredBy,
    required this.relatedModule,
    required this.actionRoute,
    this.relatedId,
    this.relatedItem,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String shortDescription;
  final String fullDescription;
  final NotificationCategory category;
  final NotificationPriority priority;
  final DateTime createdAt;
  final String triggeredBy;
  final NotificationRelatedModule relatedModule;
  final String? relatedId;
  final String? relatedItem;
  final String actionRoute;
  final bool isRead;

  SeedRoverNotification copyWith({
    bool? isRead,
  }) {
    return SeedRoverNotification(
      id: id,
      title: title,
      shortDescription: shortDescription,
      fullDescription: fullDescription,
      category: category,
      priority: priority,
      createdAt: createdAt,
      triggeredBy: triggeredBy,
      relatedModule: relatedModule,
      relatedId: relatedId,
      relatedItem: relatedItem,
      actionRoute: actionRoute,
      isRead: isRead ?? this.isRead,
    );
  }
}

String notificationRouteFor(SeedRoverNotification notification) {
  if (notification.actionRoute.isNotEmpty) {
    return notification.actionRoute;
  }

  return switch (notification.relatedModule) {
    NotificationRelatedModule.inventory =>
      AppRoutes.stockDetailsPath(notification.relatedId ?? ''),
    NotificationRelatedModule.crops =>
      AppRoutes.cropDetailsPath(notification.relatedId ?? ''),
    NotificationRelatedModule.rover ||
    NotificationRelatedModule.camera => AppRoutes.rover,
    NotificationRelatedModule.planting =>
      AppRoutes.plantingLogDetailsPath(notification.relatedId ?? ''),
    NotificationRelatedModule.users =>
      AppRoutes.userDetailsPath(notification.relatedId ?? ''),
    NotificationRelatedModule.dashboard => AppRoutes.dashboard,
    NotificationRelatedModule.system => AppRoutes.notifications,
  };
}
