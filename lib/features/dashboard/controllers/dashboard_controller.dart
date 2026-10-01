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
    final results = await Future.wait<Object>([
      _loadRoverOverview(now)
          .then<Object>((value) => value)
          .catchError((error) => error),
      _loadSensorSummary()
          .then<Object>((value) => value)
          .catchError((error) => error),
      _loadRecentActivities()
          .then<Object>((value) => value)
          .catchError((error) => error),
    ]);
    final roverError = results[0] is! RoverOverviewModel
        ? 'Rover status is unavailable.'
        : null;
    final sensorError = results[1] is! List<SensorSummaryModel>
        ? 'Sensor summary is unavailable.'
        : null;
    final activityError = results[2] is! List<ActivityPreviewModel>
        ? 'Recent activity is unavailable.'
        : null;
    if (roverError != null && sensorError != null && activityError != null) {
      throw StateError('Dashboard data is unavailable. Retry when connected.');
    }

    return DashboardModel(
      rover: results[0] is RoverOverviewModel
          ? results[0] as RoverOverviewModel
          : const RoverOverviewModel(
              unitName: 'Rover',
              status: 'Unavailable',
              plantingStatus: 'Unavailable',
              wifiConnected: false,
              bluetoothConnected: false,
              cameraConnected: false,
              isInUse: false,
              lastCommunication: null),
      sensors: results[1] is List<SensorSummaryModel>
          ? results[1] as List<SensorSummaryModel>
          : const [],
      recentActivities: results[2] is List<ActivityPreviewModel>
          ? results[2] as List<ActivityPreviewModel>
          : const [],
      roverError: roverError,
      sensorError: sensorError,
      activityError: activityError,
    );
  }

  Stream<void> watchDashboard() {
    return Stream<void>.multi((controller) {
      final subscriptions = <StreamSubscription<dynamic>>[
        _client
            .from(DatabaseTables.robotStatus)
            .stream(primaryKey: ['id']).listen((_) => controller.add(null)),
        _client
            .from(DatabaseTables.sensorReadings)
            .stream(primaryKey: ['id']).listen((_) => controller.add(null)),
        _client
            .from(DatabaseTables.activityLogs)
            .stream(primaryKey: ['id']).listen((_) => controller.add(null)),
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
        unitName: 'Rover',
        status: 'No status received',
        plantingStatus: 'Idle',
        wifiConnected: false,
        bluetoothConnected: false,
        cameraConnected: false,
        isInUse: false,
        lastCommunication: null,
      );
    }

    final row = rows.first as Map<String, dynamic>;
    final status = row['rover_status'] as String? ?? 'Offline';
    final currentActivity = row['current_activity'] as String? ?? 'Idle';
    final lastUpdated = _parseDate(row['last_updated']);
    final heartbeatFresh = lastUpdated != null &&
        now.difference(lastUpdated).abs() <= const Duration(seconds: 9);
    final active = heartbeatFresh && (status.toLowerCase() == 'online');

    return RoverOverviewModel(
      unitName: (row['rover_id'] as String?)?.trim().isNotEmpty == true
          ? (row['rover_id'] as String).trim()
          : 'Rover',
      status: heartbeatFresh ? status.toUpperCase() : 'Last seen',
      plantingStatus: currentActivity,
      wifiConnected:
          heartbeatFresh && (row['wifi_connected'] as bool? ?? false),
      bluetoothConnected:
          heartbeatFresh && (row['bluetooth_connected'] as bool? ?? false),
      cameraConnected:
          heartbeatFresh && (row['camera_connected'] as bool? ?? false),
      isInUse: active && currentActivity.toLowerCase() != 'idle',
      lastCommunication: lastUpdated,
    );
  }

  Future<List<SensorSummaryModel>> _loadSensorSummary() async {
    final now = DateTime.now();
    final rows = await _client
        .from(DatabaseTables.sensorReadings)
        .select(
            'soil_moisture, calibrated_value, soil_moisture_calibrated, calibration_version, soil_temperature, environmental_temperature, humidity, recorded_at, source')
        .eq('provenance_status', 'verified_hardware')
        .gte('recorded_at',
            now.subtract(const Duration(seconds: 60)).toUtc().toIso8601String())
        .lte('recorded_at', now.toUtc().toIso8601String())
        .order('recorded_at', ascending: false)
        .limit(1) as List<dynamic>;

    final row =
        rows.isEmpty ? <String, dynamic>{} : rows.first as Map<String, dynamic>;
    final calibrationState = row['soil_moisture_calibrated'] as bool?;
    final calibrated = calibrationState == true &&
        (row['calibration_version'] as String?)?.trim().isNotEmpty == true;
    final moisture = calibrated
        ? _sensorNumber(row['calibrated_value'] ?? row['soil_moisture'], 0, 100)
        : null;
    final humidity = _sensorNumber(row['humidity'], 0, 100);
    final soilTemperature = _sensorNumber(row['soil_temperature'], -55, 125);
    final airTemperature =
        _sensorNumber(row['environmental_temperature'], -40, 80);
    final recordedAt = _parseDate(row['recorded_at']);
    final source = row['source'] as String? ?? 'Verified rover hardware';
    final provenanceAvailable = recordedAt != null;
    String details(bool available) => available && provenanceAvailable
        ? '$source · ${_timeLabel(recordedAt)} · Fresh'
        : provenanceAvailable
            ? '$source · ${_timeLabel(recordedAt)} · Fresh · measurement unavailable'
            : 'No fresh verified reading';

    return [
      SensorSummaryModel(
        label: 'Soil Moisture',
        value: moisture?.toStringAsFixed(0) ?? '?',
        unit: '%',
        interpretation: moisture == null
            ? !provenanceAvailable
                ? 'No fresh verified reading'
                : details(false)
            : details(true),
        condition: moisture == null
            ? SensorCondition.unavailable
            : SensorCondition.recorded,
        recordedAt: recordedAt,
        source: source,
      ),
      SensorSummaryModel(
        label: 'Soil Temp',
        value: soilTemperature?.toStringAsFixed(0) ?? '?',
        unit: 'C',
        interpretation: details(soilTemperature != null),
        condition: soilTemperature == null
            ? SensorCondition.unavailable
            : SensorCondition.recorded,
        recordedAt: recordedAt,
        source: source,
      ),
      SensorSummaryModel(
        label: 'Air Temp',
        value: airTemperature?.toStringAsFixed(0) ?? '?',
        unit: 'C',
        interpretation: details(airTemperature != null),
        condition: airTemperature == null
            ? SensorCondition.unavailable
            : SensorCondition.recorded,
        recordedAt: recordedAt,
        source: source,
      ),
      SensorSummaryModel(
        label: 'Humidity',
        value: humidity?.toStringAsFixed(0) ?? '?',
        unit: '%',
        interpretation: details(humidity != null),
        condition: humidity == null
            ? SensorCondition.unavailable
            : SensorCondition.recorded,
        recordedAt: recordedAt,
        source: source,
      ),
    ];
  }

  Future<List<ActivityPreviewModel>> _loadRecentActivities() async {
    final rows = await _client
        .from(DatabaseTables.activityLogs)
        .select(
          'activity, description, module, created_at, actor:profiles!activity_logs_user_id_fkey(full_name)',
        )
        .order('created_at', ascending: false)
        .limit(5) as List<dynamic>;

    return rows.map((row) {
      final data = row as Map<String, dynamic>;
      final activity = data['activity'] as String? ?? 'SeedRover Activity';
      final description =
          data['description'] as String? ?? 'Activity recorded.';
      final actor = data['actor'] as Map<String, dynamic>?;
      final actorName = (actor?['full_name'] as String?)?.trim();

      return ActivityPreviewModel(
        title: activity,
        description: activity.toLowerCase() == 'login'
            ? actorName?.isNotEmpty == true
                ? '$actorName signed in.'
                : 'Signed in.'
            : description,
        timestamp: _parseDate(data['created_at']),
        module: data['module'] as String? ?? 'System',
      );
    }).toList(growable: false);
  }

  String _timeLabel(DateTime? value) =>
      value == null ? 'time unavailable' : value.toLocal().toString();

  DateTime? _parseDate(Object? value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString())?.toLocal();
  }

  double? _sensorNumber(Object? value, double minimum, double maximum) {
    final number = (value as num?)?.toDouble();
    return number != null &&
            number.isFinite &&
            number >= minimum &&
            number <= maximum
        ? number
        : null;
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
