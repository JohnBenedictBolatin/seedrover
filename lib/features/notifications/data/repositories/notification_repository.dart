import '../../../../core/constants/app_routes.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  const NotificationRepository();

  List<SeedRoverNotification> getNotifications() {
    return _mockNotifications;
  }
}

final _mockNotifications = <SeedRoverNotification>[
  SeedRoverNotification(
    id: 'notif-001',
    title: 'Low Stock: Peanut',
    shortDescription: 'Peanut sacks are close to the minimum stock level.',
    fullDescription:
        'Peanut inventory is nearing the configured minimum stock level. Review the item before the next market distribution.',
    category: NotificationCategory.inventory,
    priority: NotificationPriority.high,
    createdAt: DateTime(2026, 7, 5, 9, 45),
    triggeredBy: 'Inventory Monitor',
    relatedModule: NotificationRelatedModule.inventory,
    relatedId: 'stk-003',
    relatedItem: 'Peanut',
    actionRoute: AppRoutes.stockDetailsPath('stk-003'),
  ),
  SeedRoverNotification(
    id: 'notif-002',
    title: 'Out of Stock: Okra',
    shortDescription: 'Okra is currently unavailable for distribution.',
    fullDescription:
        'Okra stock reached zero after the latest market dispatch. Review the inventory item and plan the next harvest intake.',
    category: NotificationCategory.inventory,
    priority: NotificationPriority.critical,
    createdAt: DateTime(2026, 7, 5, 8, 55),
    triggeredBy: 'Inventory Monitor',
    relatedModule: NotificationRelatedModule.inventory,
    relatedId: 'stk-007',
    relatedItem: 'Okra',
    actionRoute: AppRoutes.stockDetailsPath('stk-007'),
  ),
  SeedRoverNotification(
    id: 'notif-003',
    title: 'Watering Due: Sitaw Plot A',
    shortDescription: 'Sitaw soil moisture is below the target range.',
    fullDescription:
        'Sitaw in Plot B-03 needs watering based on the latest mock sensor summary. Check crop details before taking action.',
    category: NotificationCategory.cropMonitoring,
    priority: NotificationPriority.high,
    createdAt: DateTime(2026, 7, 5, 7, 30),
    triggeredBy: 'Crop Monitor',
    relatedModule: NotificationRelatedModule.crops,
    relatedId: 'crop-002',
    relatedItem: 'Sitaw Plot B-03',
    actionRoute: AppRoutes.cropDetailsPath('crop-002'),
  ),
  SeedRoverNotification(
    id: 'notif-004',
    title: 'Fertilizer Due: Calamansi',
    shortDescription: 'Calamansi fertilizer review is due this week.',
    fullDescription:
        'Calamansi seedlings are scheduled for a fertilizer review. Open the crop record to check notes and current progress.',
    category: NotificationCategory.cropMonitoring,
    priority: NotificationPriority.medium,
    createdAt: DateTime(2026, 7, 4, 16, 20),
    triggeredBy: 'Crop Monitor',
    relatedModule: NotificationRelatedModule.crops,
    relatedId: 'crop-003',
    relatedItem: 'Calamansi',
    actionRoute: AppRoutes.cropDetailsPath('crop-003'),
    isRead: true,
  ),
  SeedRoverNotification(
    id: 'notif-005',
    title: 'Harvest Approaching: Peanut',
    shortDescription: 'Peanut harvest is approaching soon.',
    fullDescription:
        'A peanut crop is nearing its estimated harvest window. Review the crop details and maintenance history.',
    category: NotificationCategory.cropMonitoring,
    priority: NotificationPriority.medium,
    createdAt: DateTime(2026, 7, 4, 10, 10),
    triggeredBy: 'Crop Monitor',
    relatedModule: NotificationRelatedModule.crops,
    relatedId: 'crop-001',
    relatedItem: 'Peanut Plot A-01',
    actionRoute: AppRoutes.cropDetailsPath('crop-001'),
  ),
  SeedRoverNotification(
    id: 'notif-006',
    title: 'Battery Low',
    shortDescription: 'SeedRover battery has dropped below the safe threshold.',
    fullDescription:
        'The rover battery is low. Open Rover Control to review the rover status before sending movement or planting commands.',
    category: NotificationCategory.battery,
    priority: NotificationPriority.critical,
    createdAt: DateTime(2026, 7, 5, 6, 45),
    triggeredBy: 'Rover Telemetry',
    relatedModule: NotificationRelatedModule.rover,
    relatedItem: 'SeedRover Unit 01',
    actionRoute: AppRoutes.rover,
  ),
  SeedRoverNotification(
    id: 'notif-007',
    title: 'Emergency Stop Activated',
    shortDescription: 'The emergency stop was triggered during rover operation.',
    fullDescription:
        'Emergency stop is active. Open Rover Control to inspect the current rover state before resuming operations.',
    category: NotificationCategory.robot,
    priority: NotificationPriority.critical,
    createdAt: DateTime(2026, 7, 5, 6, 12),
    triggeredBy: 'SeedRover',
    relatedModule: NotificationRelatedModule.rover,
    relatedItem: 'SeedRover Unit 01',
    actionRoute: AppRoutes.rover,
  ),
  SeedRoverNotification(
    id: 'notif-008',
    title: 'Camera Disconnected',
    shortDescription: 'Live camera feed is not currently available.',
    fullDescription:
        'The rover camera connection was interrupted. Open Rover Control to check the live camera panel and connection badge.',
    category: NotificationCategory.camera,
    priority: NotificationPriority.high,
    createdAt: DateTime(2026, 7, 4, 18, 5),
    triggeredBy: 'Camera Monitor',
    relatedModule: NotificationRelatedModule.camera,
    relatedItem: 'Live Camera',
    actionRoute: AppRoutes.rover,
  ),
  SeedRoverNotification(
    id: 'notif-009',
    title: 'Planting Completed',
    shortDescription: 'SeedRover completed a Sitaw planting operation.',
    fullDescription:
        'The rover completed a planting process and recorded the activity for future planting log review.',
    category: NotificationCategory.planting,
    priority: NotificationPriority.low,
    createdAt: DateTime(2026, 7, 3, 15, 35),
    triggeredBy: 'SeedRover',
    relatedModule: NotificationRelatedModule.planting,
    relatedId: 'log-001',
    relatedItem: 'Sitaw Planting Run',
    actionRoute: AppRoutes.plantingLogDetailsPath('log-001'),
    isRead: true,
  ),
  SeedRoverNotification(
    id: 'notif-010',
    title: 'User Created',
    shortDescription: 'A new farm staff account was created.',
    fullDescription:
        'A new user profile was created. Open User Management to review the account once that module is enabled.',
    category: NotificationCategory.userManagement,
    priority: NotificationPriority.medium,
    createdAt: DateTime(2026, 7, 2, 13, 20),
    triggeredBy: 'System Administrator',
    relatedModule: NotificationRelatedModule.users,
    relatedId: 'user-001',
    relatedItem: 'Farm Staff Account',
    actionRoute: AppRoutes.userDetailsPath('user-001'),
  ),
  SeedRoverNotification(
    id: 'notif-011',
    title: 'Backup Completed',
    shortDescription: 'The daily application backup completed successfully.',
    fullDescription:
        'The daily system backup completed without issues. No immediate action is required.',
    category: NotificationCategory.system,
    priority: NotificationPriority.low,
    createdAt: DateTime(2026, 7, 1, 23, 10),
    triggeredBy: 'System',
    relatedModule: NotificationRelatedModule.system,
    relatedItem: 'Daily Backup',
    actionRoute: AppRoutes.notificationDetailsPath('notif-011'),
    isRead: true,
  ),
];
