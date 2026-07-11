import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/database_tables.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  const NotificationRepository(this._client);

  final SupabaseClient _client;

  Stream<List<SeedRoverNotification>> watchNotifications() {
    return _client
        .from(DatabaseTables.notifications)
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map(
          (rows) => rows
              .map((row) => _notificationFromRow(row))
              .toList(growable: false),
        );
  }

  Future<List<SeedRoverNotification>> getNotifications() async {
    final rows = await _client
        .from(DatabaseTables.notifications)
        .select()
        .order('created_at', ascending: false) as List<dynamic>;

    return rows
        .map((row) => _notificationFromRow(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> markAsRead(String notificationId) async {
    await _client
        .from(DatabaseTables.notifications)
        .update({'is_read': true})
        .eq('id', notificationId);
    await _recordActivity('Notification Read');
  }

  Future<void> markAsUnread(String notificationId) async {
    await _client
        .from(DatabaseTables.notifications)
        .update({'is_read': false})
        .eq('id', notificationId);
  }

  Future<void> deleteNotification(String notificationId) async {
    await _client
        .from(DatabaseTables.notifications)
        .delete()
        .eq('id', notificationId);
  }

  SeedRoverNotification _notificationFromRow(Map<String, dynamic> row) {
    final type = row['notification_type'] as String? ?? 'System';
    final route = row['action_route'] as String? ?? AppRoutes.notifications;

    return SeedRoverNotification(
      id: row['id'] as String,
      title: row['title'] as String? ?? 'SeedRover Notification',
      shortDescription: row['message'] as String? ?? '',
      fullDescription: row['message'] as String? ?? '',
      category: _categoryFromDb(type),
      priority: _priorityFromTitle(row['title'] as String? ?? '', type),
      createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
      triggeredBy: type,
      relatedModule: _relatedModuleFromRoute(route, type),
      relatedId: _relatedIdFromRoute(route),
      relatedItem: row['title'] as String?,
      actionRoute: route,
      isRead: row['is_read'] as bool? ?? false,
    );
  }

  Future<void> _recordActivity(String activity) async {
    await _client.from(DatabaseTables.activityLogs).insert({
      'user_id': _client.auth.currentUser?.id,
      'activity': activity,
      'description': 'Notification status updated.',
      'module': 'Notifications',
    });
  }

  NotificationCategory _categoryFromDb(String type) {
    return switch (type) {
      'Battery' => NotificationCategory.battery,
      'Seed Level' => NotificationCategory.robot,
      'Inventory' => NotificationCategory.inventory,
      'Robot Status' => NotificationCategory.robot,
      'Crop Reminder' => NotificationCategory.cropMonitoring,
      _ => NotificationCategory.system,
    };
  }

  NotificationPriority _priorityFromTitle(String title, String type) {
    final normalizedTitle = title.toLowerCase();

    if (normalizedTitle.contains('emergency') ||
        normalizedTitle.contains('out of stock')) {
      return NotificationPriority.critical;
    }

    if (normalizedTitle.contains('low') || type == 'Battery') {
      return NotificationPriority.high;
    }

    if (type == 'System') {
      return NotificationPriority.low;
    }

    return NotificationPriority.medium;
  }

  NotificationRelatedModule _relatedModuleFromRoute(String route, String type) {
    if (route.startsWith(AppRoutes.stocks)) {
      return NotificationRelatedModule.inventory;
    }

    if (route.startsWith(AppRoutes.crops)) {
      return NotificationRelatedModule.crops;
    }

    if (route.startsWith(AppRoutes.rover)) {
      return type == 'Camera'
          ? NotificationRelatedModule.camera
          : NotificationRelatedModule.rover;
    }

    if (route.startsWith('/users')) {
      return NotificationRelatedModule.users;
    }

    if (route.startsWith('/planting-logs')) {
      return NotificationRelatedModule.planting;
    }

    if (route.startsWith(AppRoutes.dashboard)) {
      return NotificationRelatedModule.dashboard;
    }

    return NotificationRelatedModule.system;
  }

  String? _relatedIdFromRoute(String route) {
    final parts = route.split('/').where((part) => part.isNotEmpty).toList();

    if (parts.length < 2) {
      return null;
    }

    return parts.last;
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString())?.toLocal();
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(supabaseClientProvider)),
);
