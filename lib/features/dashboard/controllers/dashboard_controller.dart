import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/database_tables.dart';
import '../../../core/services/supabase_service.dart';
import '../data/models/dashboard_model.dart';

class DashboardController {
  const DashboardController(this._client);

  final SupabaseClient _client;

  Future<DashboardModel> loadDashboard() async {
    final now = DateTime.now();
    final rover = await _loadRoverOverview(now);
    final sensors = await _loadSensorSummary();
    final activities = await _loadRecentActivities();

    return DashboardModel(
      rover: rover,
      sensors: sensors,
      recentActivities: activities,
    );
  }

  Stream<void> watchDashboard() {
    return Stream<void>.multi((controller) {
      final subscriptions = <StreamSubscription<dynamic>>[
        _client
            .from(DatabaseTables.robotStatus)
            .stream(primaryKey: ['id'])
            .listen((_) => controller.add(null)),
        _client
            .from(DatabaseTables.sensorReadings)
            .stream(primaryKey: ['id'])
            .listen((_) => controller.add(null)),
        _client
            .from(DatabaseTables.activityLogs)
            .stream(primaryKey: ['id'])
            .listen((_) => controller.add(null)),
      ];

      controller.onCancel = () {
        for (final subscription in subscriptions) {
          subscription.cancel();
        }
      };
    });
  }

  Future<RoverOverviewModel> _loadRoverOverview(DateTime now) async {
    final rows = await _client
        .from(DatabaseTables.robotStatus)
        .select()
        .eq('is_active', true)
        .limit(1) as List<dynamic>;

    if (rows.isEmpty) {
      return RoverOverviewModel(
        unitName: 'SeedRover Unit SR-001',
        status: 'OFFLINE',
        plantingStatus: 'Idle',
        batteryLevel: 0,
        seedLevel: 0,
        wifiConnected: false,
        bluetoothConnected: false,
        cameraConnected: false,
        isInUse: false,
        usageDuration: Duration.zero,
        lastCommunication: now,
      );
    }

    final row = rows.first as Map<String, dynamic>;
    final status = row['rover_status'] as String? ?? 'Offline';
    final currentActivity = row['current_activity'] as String? ?? 'Idle';
    final lastUpdated = _parseDate(row['last_updated']) ?? now;

    return RoverOverviewModel(
      unitName: 'SeedRover Unit SR-001',
      status: status.toUpperCase(),
      plantingStatus: currentActivity,
      batteryLevel: row['battery_level'] as int? ?? 0,
      seedLevel: row['seed_level'] as int? ?? 0,
      wifiConnected: row['wifi_connected'] as bool? ?? false,
      bluetoothConnected: row['bluetooth_connected'] as bool? ?? false,
      cameraConnected: row['camera_connected'] as bool? ?? false,
      isInUse: currentActivity.toLowerCase() != 'idle',
      usageDuration: _absoluteDuration(now.difference(lastUpdated)),
      lastCommunication: lastUpdated,
    );
  }

  Future<List<SensorSummaryModel>> _loadSensorSummary() async {
    final rows = await _client
        .from(DatabaseTables.sensorReadings)
        .select()
        .order('recorded_at', ascending: false)
        .limit(1) as List<dynamic>;

    if (rows.isEmpty) {
      return const [
        SensorSummaryModel(
          label: 'Soil Moisture',
          value: '0',
          unit: '%',
          interpretation: 'Waiting',
          condition: SensorCondition.moderate,
        ),
        SensorSummaryModel(
          label: 'Soil Temp',
          value: '0',
          unit: 'C',
          interpretation: 'Waiting',
          condition: SensorCondition.moderate,
        ),
        SensorSummaryModel(
          label: 'Air Temp',
          value: '0',
          unit: 'C',
          interpretation: 'Waiting',
          condition: SensorCondition.moderate,
        ),
        SensorSummaryModel(
          label: 'Humidity',
          value: '0',
          unit: '%',
          interpretation: 'Waiting',
          condition: SensorCondition.moderate,
        ),
      ];
    }

    final row = rows.first as Map<String, dynamic>;
    final moisture = _toDouble(row['soil_moisture']);
    final humidity = _toDouble(row['humidity']);

    return [
      SensorSummaryModel(
        label: 'Soil Moisture',
        value: moisture.toStringAsFixed(0),
        unit: '%',
        interpretation: _percentageLabel(moisture),
        condition: _conditionForPercent(moisture),
      ),
      SensorSummaryModel(
        label: 'Soil Temp',
        value: _toDouble(row['soil_temperature']).toStringAsFixed(0),
        unit: 'C',
        interpretation: 'Live',
        condition: SensorCondition.excellent,
      ),
      SensorSummaryModel(
        label: 'Air Temp',
        value: _toDouble(row['environmental_temperature']).toStringAsFixed(0),
        unit: 'C',
        interpretation: 'Live',
        condition: SensorCondition.excellent,
      ),
      SensorSummaryModel(
        label: 'Humidity',
        value: humidity.toStringAsFixed(0),
        unit: '%',
        interpretation: _percentageLabel(humidity),
        condition: _conditionForPercent(humidity),
      ),
    ];
  }

  Future<List<ActivityPreviewModel>> _loadRecentActivities() async {
    final rows = await _client
        .from(DatabaseTables.activityLogs)
        .select('activity, description, module, created_at')
        .order('created_at', ascending: false)
        .limit(5) as List<dynamic>;

    return rows.map((row) {
      final data = row as Map<String, dynamic>;

      return ActivityPreviewModel(
        title: data['activity'] as String? ?? 'SeedRover Activity',
        description: data['description'] as String? ?? 'Activity recorded.',
        timestamp: _parseDate(data['created_at']) ?? DateTime.now(),
        module: data['module'] as String? ?? 'System',
      );
    }).toList(growable: false);
  }

  String _percentageLabel(double value) {
    if (value >= 55) {
      return 'Good';
    }

    if (value >= 35) {
      return 'Moderate';
    }

    return 'Low';
  }

  SensorCondition _conditionForPercent(double value) {
    if (value >= 55) {
      return SensorCondition.excellent;
    }

    if (value >= 35) {
      return SensorCondition.moderate;
    }

    return SensorCondition.poor;
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString())?.toLocal();
  }

  double _toDouble(Object? value) {
    return (value as num?)?.toDouble() ?? 0;
  }

  Duration _absoluteDuration(Duration value) {
    if (!value.isNegative) {
      return value;
    }

    return Duration(microseconds: -value.inMicroseconds);
  }
}

final dashboardControllerProvider = Provider<DashboardController>(
  (ref) => DashboardController(ref.watch(supabaseClientProvider)),
);

final dashboardProvider = FutureProvider<DashboardModel>(
  (ref) => ref.watch(dashboardControllerProvider).loadDashboard(),
);

final dashboardRealtimeProvider = StreamProvider<void>(
  (ref) => ref.watch(dashboardControllerProvider).watchDashboard(),
);
