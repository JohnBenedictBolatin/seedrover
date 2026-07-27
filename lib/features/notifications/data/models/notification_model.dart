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
  final sanitizedActionRoute = _sanitizeNotificationRoute(
    notification.actionRoute,
  );

  if (sanitizedActionRoute != null) {
    return sanitizedActionRoute;
  }

  return switch (notification.relatedModule) {
    NotificationRelatedModule.inventory => _detailsOrList(
        notification.relatedId, AppRoutes.stocks, AppRoutes.stockDetailsPath),
    NotificationRelatedModule.crops => _detailsOrList(
        notification.relatedId, AppRoutes.crops, AppRoutes.cropDetailsPath),
    NotificationRelatedModule.rover ||
    NotificationRelatedModule.camera =>
      AppRoutes.rover,
    NotificationRelatedModule.planting => _detailsOrList(
        notification.relatedId,
        AppRoutes.rover,
        AppRoutes.plantingLogDetailsPath,
      ),
    NotificationRelatedModule.users => _detailsOrList(
        notification.relatedId, AppRoutes.profile, AppRoutes.userDetailsPath),
    NotificationRelatedModule.dashboard => AppRoutes.dashboard,
    NotificationRelatedModule.system => AppRoutes.notifications,
  };
}

String _detailsOrList(
  String? id,
  String fallbackRoute,
  String Function(String id) detailsRoute,
) {
  final normalizedId = id?.trim();

  if (normalizedId == null || normalizedId.isEmpty) {
    return fallbackRoute;
  }

  return detailsRoute(normalizedId);
}

String? _sanitizeNotificationRoute(String route) {
  final normalized = route.trim();

  if (normalized.isEmpty) {
    return null;
  }

  final lower = normalized.toLowerCase();

  if (lower == 'home' || lower == '/home') {
    return null;
  }

  if (lower == 'dashboard') {
    return AppRoutes.dashboard;
  }

  if (lower == 'rover') {
    return AppRoutes.rover;
  }

  if (lower == 'crops') {
    return AppRoutes.crops;
  }

  if (lower == 'stocks' || lower == 'inventory' || lower == '/inventory') {
    return AppRoutes.stocks;
  }

  if (lower == '/rover-monitor') {
    return AppRoutes.rover;
  }

  if (lower == 'notifications') {
    return AppRoutes.notifications;
  }

  if (lower == 'profile' || lower == 'users') {
    return AppRoutes.profile;
  }

  if (!normalized.startsWith('/')) {
    return null;
  }

  if (normalized == AppRoutes.dashboard ||
      normalized == AppRoutes.rover ||
      normalized == AppRoutes.crops ||
      normalized == AppRoutes.stocks ||
      normalized == AppRoutes.notifications ||
      normalized == AppRoutes.profile) {
    return normalized;
  }

  if (normalized.startsWith('${AppRoutes.crops}/') &&
      normalized.length > AppRoutes.crops.length + 1) {
    return normalized;
  }

  if (normalized.startsWith('${AppRoutes.stocks}/') &&
      normalized.length > AppRoutes.stocks.length + 1) {
    return normalized;
  }

  if (normalized.startsWith('/planting-logs/') &&
      normalized.length > '/planting-logs/'.length) {
    return normalized;
  }

  if (normalized.startsWith('/users/') &&
      normalized.length > '/users/'.length) {
    return normalized;
  }

  return null;
}
