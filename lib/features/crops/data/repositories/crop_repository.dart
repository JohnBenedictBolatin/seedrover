import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';

import '../../../../core/constants/database_tables.dart';
import '../../../../core/config/app_environment.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/business_calendar.dart';
import '../models/crop_model.dart';

class CropRepository {
  CropRepository(this._client, {this.webAdminUrl = ''});

  static const _cropImagesBucket = 'crop-images';
  static const _sensorDraftStoragePrefix = 'pending_crop_sensor_checks_v1_';
  static const _plantingNameDraftStoragePrefix =
      'pending_crop_planting_names_v1_';

  final SupabaseClient _client;
  final String webAdminUrl;
  Future<void> _sensorQueueWrites = Future<void>.value();
  Future<int>? _sensorSyncInFlight;

  Stream<void> watchCrops() {
    return Stream<void>.multi((controller) {
      final channel = _client
          .channel('crop-monitoring:${DateTime.now().microsecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: DatabaseTables.crops,
            callback: (_) => controller.add(null),
          )
          .subscribe((status, _) {
            if (status == RealtimeSubscribeStatus.subscribed) {
              controller.add(null);
            }
          });
      controller.onCancel = () => _client.removeChannel(channel);
    });
  }

  Future<CropWeatherSnapshot> getWeatherStatus() async {
    return _getWeatherApiForecast();
  }

  Future<CropWeatherSnapshot> _getWeatherApiForecast() async {
    final baseUrl = webAdminUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final accessToken = _client.auth.currentSession?.accessToken;
    if (baseUrl.isEmpty) {
      return const CropWeatherSnapshot(
        currentCondition: 'Weather unavailable',
        unavailableMessage: 'Weather service URL is not configured.',
      );
    }
    if (accessToken == null || accessToken.isEmpty) {
      return const CropWeatherSnapshot(
        currentCondition: 'Weather unavailable',
        unavailableMessage: 'Sign in again to load the weather forecast.',
      );
    }

    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await httpClient
          .getUrl(Uri.parse('$baseUrl/api/weather'))
          .timeout(const Duration(seconds: 6));
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $accessToken')
        ..set(HttpHeaders.acceptHeader, 'application/json');
      final response =
          await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode != HttpStatus.ok) {
        final message = switch (response.statusCode) {
          HttpStatus.unauthorized =>
            'Your session expired. Sign in again to load the forecast.',
          HttpStatus.serviceUnavailable =>
            'WeatherAPI is unavailable. Check the server API key and try again.',
          HttpStatus.notFound =>
            'The mobile weather endpoint is not deployed on the configured web server yet.',
          _ => 'Weather service returned an error (${response.statusCode}).',
        };
        return CropWeatherSnapshot(
          currentCondition: 'Weather unavailable',
          unavailableMessage: message,
        );
      }

      final payload = jsonDecode(await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 5)));
      if (payload is! Map<String, dynamic>) {
        return const CropWeatherSnapshot(
          currentCondition: 'Weather unavailable',
          unavailableMessage: 'Weather service returned an invalid response.',
        );
      }

      double? numberValue(Object? value) =>
          value is num && value.isFinite ? value.toDouble() : null;
      DateTime? dateValue(Object? value) =>
          value is String ? DateTime.tryParse(value) : null;

      return CropWeatherSnapshot(
        source: payload['source'] as String? ?? 'WeatherAPI',
        currentCondition:
            payload['currentCondition'] as String? ?? 'Weather unavailable',
        temperatureC: numberValue(payload['temperatureC']),
        rainChancePercent: numberValue(payload['rainChancePercent']),
        nextRainAt: dateValue(payload['nextRainWindow']),
        fetchedAt: dateValue(payload['fetchedAt']),
      );
    } catch (_) {
      return const CropWeatherSnapshot(
        currentCondition: 'Weather unavailable',
        unavailableMessage:
            'Could not reach WeatherAPI. Check that this device has internet access.',
      );
    } finally {
      httpClient.close(force: true);
    }
  }

  Future<List<CropSensorReading>> getSensorHistory(String cropId) async {
    if (cropId.trim().isEmpty) {
      throw ArgumentError.value(cropId, 'cropId', 'Crop record is required.');
    }

    final rows = await _client
        .from(DatabaseTables.sensorReadings)
        .select(
          'id, soil_raw, soil_moisture, calibrated_value, soil_temperature, environmental_temperature, humidity, source, recorded_at, provenance_status, soil_moisture_calibrated, calibration_version',
        )
        .eq('crop_id', cropId)
        .order('recorded_at', ascending: false)
        .limit(100) as List<dynamic>;

    final readings = <CropSensorReading>[];
    for (final value in rows) {
      final row = value as Map<String, dynamic>;
      final recordedAt = _parseDateTime(row['recorded_at']);
      if (recordedAt == null) {
        continue;
      }
      final calibrationVersion = row['calibration_version']?.toString();
      final moistureCalibrated = row['soil_moisture_calibrated'] == true &&
          calibrationVersion?.trim().isNotEmpty == true;

      readings.add(CropSensorReading(
        id: row['id'] as String,
        recordedAt: recordedAt,
        source: row['source']?.toString() ?? 'Source unavailable',
        provenanceStatus: row['provenance_status']?.toString() ?? 'unverified',
        soilRaw: _sensorNumber(row['soil_raw'], 1, 4094)?.toInt(),
        soilMoisture: moistureCalibrated
            ? _sensorNumber(
                row['calibrated_value'] ?? row['soil_moisture'], 0, 100)
            : null,
        soilTemperature: _sensorNumber(row['soil_temperature'], -55, 125),
        environmentTemperature:
            _sensorNumber(row['environmental_temperature'], -40, 80),
        humidity: _sensorNumber(row['humidity'], 0, 100),
        soilMoistureCalibrated: row['soil_moisture_calibrated'] == false
            ? false
            : moistureCalibrated
                ? true
                : null,
        calibrationVersion: calibrationVersion,
      ));
    }
    return readings;
  }

  Future<List<CropModel>> getCrops() async {
    final rows = await _client
        .from(DatabaseTables.crops)
        .select(
          'id, batch_code, crop_name, assigned_planting_name, custom_planting_name, planting_name_version, assigned_manager, planting_date, estimated_harvest, '
          'growth_stage, maintenance_notes, image_path, crop_status, crop_profile_key, harvest_mode, created_at, '
          'updated_at, planting_source, field_label, field_area_m2, harvest_window_start, '
          'harvest_window_end, forecast_confidence, expected_stage, current_care_status, '
          'propagation_method, last_watered_at, harvested_at, planting_log_id, completed_drop_cycles, '
          'crop_profiles(stage_plan), profiles(full_name)',
        )
        .order('planting_date', ascending: false) as List<dynamic>;
    final plantingLogIds = rows
        .map((r) => (r as Map<String, dynamic>)['planting_log_id'])
        .whereType<String>()
        .toSet()
        .toList();
    final cropIds =
        rows.map((r) => (r as Map<String, dynamic>)['id'] as String).toList();
    final now = BusinessCalendar.now();
    final relatedRowsFuture = Future.wait<List<dynamic>>([
      () async {
        if (plantingLogIds.isEmpty) return <dynamic>[];
        return await _client
            .from('planting_logs')
            .select(
                'id, crop_id, target_drop_cycles, completed_drop_cycles, field_label, started_at')
            .inFilter('id', plantingLogIds) as List<dynamic>;
      }(),
      () async {
        if (cropIds.isEmpty) return <dynamic>[];
        return await _client.rpc('get_crop_harvest_summaries', params: {
          'p_crop_ids': cropIds,
        }) as List<dynamic>;
      }(),
      () async {
        if (cropIds.isEmpty) return <dynamic>[];
        return await _client
            .from('planting_logs')
            .select(
                'id, crop_id, target_drop_cycles, completed_drop_cycles, field_label, started_at')
            .inFilter('crop_id', cropIds)
            .order('started_at', ascending: false) as List<dynamic>;
      }(),
      () async {
        if (cropIds.isEmpty) return <dynamic>[];
        return await _client
            .from('crop_tasks')
            .select(
                'id,crop_id,task_type,title,recommendation,recommendation_data,due_at,priority,status')
            .inFilter('crop_id', cropIds)
            .inFilter('status', [
          'Due',
          'Overdue',
          'Upcoming',
          'Postponed'
        ]).order('due_at') as List<dynamic>;
      }(),
      (() async => await _client
          .from('crop_profile_images')
          .select('profile_key, image_path') as List<dynamic>)(),
      () async {
        if (cropIds.isEmpty) return <dynamic>[];
        return await _client.rpc('get_crop_activity_summaries', params: {
          'p_crop_ids': cropIds,
          'p_week_start': BusinessCalendar.startOfWeek(now).toIso8601String(),
          'p_as_of': now.toIso8601String(),
        }) as List<dynamic>;
      }(),
    ]);
    final sensorSnapshotsFuture = _latestSensorSnapshots(cropIds);
    final relatedRows = await relatedRowsFuture;
    final sensorSnapshots = await sensorSnapshotsFuture;
    final plantingLogs = relatedRows[0];
    final harvestSummaryRows = relatedRows[1];
    final harvestSummaries = <String, Map<String, dynamic>>{
      for (final value in harvestSummaryRows)
        if (value is Map<String, dynamic>) value['crop_id'] as String: value,
    };
    final cropPlantingLogs = relatedRows[2];
    final plantingLogsById = <String, Map<String, dynamic>>{
      for (final value in plantingLogs)
        if (value is Map<String, dynamic>) value['id'] as String: value,
    };
    final plantingLogsByCropId = <String, Map<String, dynamic>>{};
    for (final value in cropPlantingLogs) {
      if (value is Map<String, dynamic> && value['crop_id'] is String) {
        plantingLogsByCropId.putIfAbsent(
            value['crop_id'] as String, () => value);
      }
    }
    final taskRows = relatedRows[3];
    final imageRows = relatedRows[4];
    final activitySummaryRows = relatedRows[5];
    final activitySummaries = <String, Map<String, dynamic>>{
      for (final value in activitySummaryRows)
        if (value is Map<String, dynamic>) value['crop_id'] as String: value,
    };
    final seedImages = <String, String>{};
    for (final value in imageRows) {
      if (value is Map<String, dynamic> &&
          value['profile_key'] is String &&
          value['image_path'] is String) {
        seedImages[value['profile_key'] as String] =
            value['image_path'] as String;
      }
    }
    final loadedCrops = await Future.wait(
      rows.map((row) async {
        final cropRow = row as Map<String, dynamic>;
        final cropId = cropRow['id'] as String;
        final plantingLog = plantingLogsById[cropRow['planting_log_id']] ??
            plantingLogsByCropId[cropId];
        final latestDropCycles =
            (activitySummaries[cropId]?['latest_drop_cycles'] as num?)?.toInt();
        return _cropFromRow(
          {
            ...cropRow,
            'planting_target_drops': plantingLog?['target_drop_cycles'],
            'planting_completed_drops': plantingLog?['completed_drop_cycles'] ??
                cropRow['completed_drop_cycles'] ??
                latestDropCycles,
            'planting_field_label':
                plantingLog?['field_label'] ?? cropRow['field_label'],
            'harvest_summary': harvestSummaries[cropId],
          },
          sensorSnapshots[cropId] ??
              const CropSensorSnapshot(
                soilMoisture: null,
                soilRaw: null,
                soilTemperature: null,
                environmentTemperature: null,
                humidity: null,
              ),
          seedImages: seedImages,
          tasks: (taskRows.where((value) =>
                  (value as Map<String, dynamic>)['crop_id'] == cropId))
              .map((value) {
            final t = value as Map<String, dynamic>;
            return CropCareTask(
                id: t['id'] as String,
                title: t['title'] as String,
                recommendation: t['recommendation'] as String,
                type: t['task_type'] as String,
                suggestedWaterMl: t['task_type'] == 'Water' &&
                        t['recommendation_data'] is Map
                    ? _litersToMilliliters(
                        (t['recommendation_data'] as Map)['estimated_liters'])
                    : null,
                dueAt: _parseDateTime(t['due_at']) ??
                    DateTime.fromMillisecondsSinceEpoch(0),
                priority: t['priority'] as String,
                status: t['status'] as String);
          }).toList(),
        );
      }),
    );
    final nameDrafts = await _pendingPlantingNameDrafts();
    return loadedCrops.map((crop) {
      Map<String, dynamic>? draft;
      for (final item in nameDrafts) {
        if (item['crop_id'] == crop.id) {
          draft = item;
          break;
        }
      }
      if (draft == null) return crop;
      return crop.copyWith(
        customPlantingName: draft['planting_name'] as String?,
        plantingNameSyncStatus: draft['status'] as String? ?? 'Waiting to sync',
      );
    }).toList(growable: false);
  }

  Future<CropModel> updateCrop(CropModel crop) async {
    final row = await _client
        .from(DatabaseTables.crops)
        .update(_cropPayload(crop))
        .eq('id', crop.id)
        .select(
          'id, batch_code, crop_name, assigned_planting_name, custom_planting_name, planting_name_version, assigned_manager, planting_date, estimated_harvest, '
          'growth_stage, maintenance_notes, image_path, crop_status, crop_profile_key, created_at, '
          'updated_at, planting_source, field_label, field_area_m2, harvest_window_start, '
          'harvest_window_end, forecast_confidence, expected_stage, current_care_status, '
          'propagation_method, last_watered_at, harvested_at, planting_log_id, completed_drop_cycles, '
          'crop_profiles(stage_plan), profiles(full_name)',
        )
        .single();

    await _recordActivity(
      activity: 'Crop record updated',
      description: '${crop.name} crop record updated.',
    );

    final plantingLogId = row['planting_log_id'] as String?;
    final plantingLogQuery = _client
        .from('planting_logs')
        .select('target_drop_cycles, completed_drop_cycles, field_label');
    final plantingLog = plantingLogId == null
        ? await plantingLogQuery
            .eq('crop_id', crop.id)
            .order('started_at', ascending: false)
            .limit(1)
            .maybeSingle()
        : await plantingLogQuery.eq('id', plantingLogId).maybeSingle();
    final history = await _activityHistory(crop.id);
    int? activityDropCount;
    for (final record in history) {
      if (record.unit?.trim().toLowerCase() == 'drop cycles' &&
          record.quantity != null) {
        activityDropCount = record.quantity!.round();
        break;
      }
    }

    return _cropFromRow(
      {
        ...row,
        'planting_target_drops': plantingLog?['target_drop_cycles'],
        'planting_completed_drops': plantingLog?['completed_drop_cycles'] ??
            row['completed_drop_cycles'] ??
            activityDropCount,
        'planting_field_label':
            plantingLog?['field_label'] ?? row['field_label'],
      },
      await _latestSensorSnapshot(cropId: crop.id),
      maintenanceHistory: history,
    );
  }

  Future<void> deleteCrop(String cropId) async {
    await _client.from(DatabaseTables.crops).delete().eq('id', cropId);
    await _recordActivity(
      activity: 'Crop record deleted',
      description: 'Crop record deleted.',
    );
  }

  Future<bool> recordSensorCheck({
    required String cropId,
    required Map<String, dynamic> readings,
  }) async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) {
      throw StateError('Sign in again before saving this sensor reading.');
    }
    final queuedReadings = Map<String, dynamic>.from(readings)
      ..putIfAbsent('client_reading_id', _newUuid);
    try {
      await _submitSensorCheck(cropId, queuedReadings);
      return true;
    } catch (error) {
      if (!_looksOffline(error)) rethrow;
      await _saveSensorCheckDraft(ownerId, cropId, queuedReadings);
      return false;
    }
  }

  Future<int> pendingSensorCheckCount() async {
    return (await pendingSensorChecks()).length;
  }

  Future<List<Map<String, dynamic>>> pendingSensorChecks() async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) return const [];
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_sensorDraftKey(ownerId));
    if (raw == null || raw.isEmpty) return const [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList(growable: false);
  }

  Future<int> retryPendingSensorChecks() {
    final activeSync = _sensorSyncInFlight;
    if (activeSync != null) return activeSync;
    final sync = _retryPendingSensorChecksOnce();
    _sensorSyncInFlight = sync;
    return sync.whenComplete(() {
      if (identical(_sensorSyncInFlight, sync)) _sensorSyncInFlight = null;
    });
  }

  Future<int> _retryPendingSensorChecksOnce() async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) return 0;
    final preferences = await SharedPreferences.getInstance();
    final storageKey = _sensorDraftKey(ownerId);
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return 0;
    final queued = (jsonDecode(raw) as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList(growable: false);
    final syncedIds = <String>{};
    var synced = 0;
    for (var index = 0; index < queued.length; index++) {
      final draft = queued[index];
      try {
        await _submitSensorCheck(
          draft['crop_id'] as String,
          Map<String, dynamic>.from(draft['readings'] as Map),
        );
        synced++;
        syncedIds.add(
          (draft['readings'] as Map)['client_reading_id']?.toString() ?? '',
        );
      } catch (_) {
        break;
      }
    }
    await _serializeSensorQueue(() async {
      // A new reading may have been queued while uploads were in flight. Merge
      // against the latest persisted queue so that it is never overwritten.
      final latestRaw = preferences.getString(storageKey);
      final latest = latestRaw == null || latestRaw.isEmpty
          ? <Map<String, dynamic>>[]
          : (jsonDecode(latestRaw) as List<dynamic>)
              .map((value) => Map<String, dynamic>.from(value as Map))
              .toList();
      final remaining = latest.where((draft) {
        final id =
            (draft['readings'] as Map?)?['client_reading_id']?.toString();
        return !syncedIds.contains(id);
      }).toList();
      if (remaining.isEmpty) {
        await preferences.remove(storageKey);
      } else {
        await preferences.setString(storageKey, jsonEncode(remaining));
      }
    });
    return synced;
  }

  Future<void> _submitSensorCheck(
    String cropId,
    Map<String, dynamic> readings,
  ) async {
    await _client.rpc('record_crop_sensor_check', params: {
      'p_crop_id': cropId,
      'p_client_reading_id': readings['client_reading_id'],
      'p_soil_raw': (readings['soil_raw'] as num?)?.toInt(),
      'p_soil_moisture':
          (readings['soil_moisture_percent'] as num?)?.toDouble(),
      'p_soil_temperature':
          (readings['soil_temperature_c'] as num?)?.toDouble(),
      'p_air_temperature': (readings['air_temperature_c'] as num?)?.toDouble(),
      'p_humidity': (readings['humidity_percent'] as num?)?.toDouble(),
      'p_rover_id': 'SeedRover-01',
      'p_recorded_at': readings['recorded_at']?.toString(),
      'p_soil_moisture_calibrated':
          readings['soil_moisture_calibrated'] as bool?,
      'p_calibration_version': readings['calibration_version']?.toString(),
      'p_firmware_version': readings['firmware_version']?.toString(),
    });
  }

  Future<void> _saveSensorCheckDraft(
    String ownerId,
    String cropId,
    Map<String, dynamic> readings,
  ) async {
    await _serializeSensorQueue(() async {
      final preferences = await SharedPreferences.getInstance();
      final key = _sensorDraftKey(ownerId);
      final raw = preferences.getString(key);
      final drafts = raw == null || raw.isEmpty
          ? <Map<String, dynamic>>[]
          : (jsonDecode(raw) as List<dynamic>)
              .map((value) => Map<String, dynamic>.from(value as Map))
              .toList();
      final readingId = readings['client_reading_id'];
      if (!drafts.any((draft) =>
          (draft['readings'] as Map?)?['client_reading_id'] == readingId)) {
        drafts.add({'crop_id': cropId, 'readings': readings});
      }
      await preferences.setString(key, jsonEncode(drafts));
    });
  }

  String _sensorDraftKey(String ownerId) =>
      '$_sensorDraftStoragePrefix$ownerId';

  Future<T> _serializeSensorQueue<T>(Future<T> Function() write) {
    final result = _sensorQueueWrites.then((_) => write());
    _sensorQueueWrites =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<Map<String, dynamic>> recordCropEntry({
    required String cropId,
    required CropMaintenanceActivity activity,
    required DateTime date,
    String? notes,
    double? quantity,
    String? unit,
    String? material,
    String? observedStage,
    String? taskId,
    String? submissionId,
    DateTime? nextCheckOn,
    List<String> photoFiles = const [],
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in before recording crop care.');
    final id = submissionId ?? _newUuid();
    final activityType = switch (activity) {
      CropMaintenanceActivity.planted ||
      CropMaintenanceActivity.stageObserved =>
        'Stage Observed',
      CropMaintenanceActivity.watered => 'Watered',
      CropMaintenanceActivity.fertilized => 'Fertilized',
      CropMaintenanceActivity.inspected => 'Inspected',
      CropMaintenanceActivity.transplanted => 'Transplanted',
      CropMaintenanceActivity.harvested => 'Harvested',
      CropMaintenanceActivity.notHarvested => 'Not Harvested',
      CropMaintenanceActivity.plantingFailed => 'Not Harvested',
    };
    final entry = <String, dynamic>{
      'crop_id': cropId,
      'activity_type': activityType,
      'performed_at': date.toUtc().toIso8601String(),
      'quantity': quantity,
      'unit': activity == CropMaintenanceActivity.harvested ? 'kg' : unit,
      'material': material,
      'notes': notes,
      'observed_stage': observedStage,
      'task_id': taskId,
      'submission_id': id,
      'next_check_on': nextCheckOn?.toIso8601String().substring(0, 10),
      'harvest_version':
          activity == CropMaintenanceActivity.harvested ? 2 : null,
    };
    var durablePhotos = const <String>[];
    var uploadedPhotoPaths = const <String>[];
    try {
      if (activity == CropMaintenanceActivity.harvested) {
        final pendingHarvest = (await getCareDrafts(userId: userId)).any(
            (draft) =>
                draft['crop_id'] == cropId &&
                draft['activity_type'] == 'Harvested' &&
                draft['submission_id'] != id &&
                draft['status'] != 'Synced');
        if (pendingHarvest) {
          throw StateError(
              'Resolve this crop\'s saved harvest before recording another.');
        }
        final crop = await _client
            .from('crops')
            .select('harvest_mode')
            .eq('id', cropId)
            .single();
        if (crop['harvest_mode'] == 'repeat') {
          final draft = {
            ...entry,
            'status': 'Syncing',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          };
          await _saveDraft(userId, id, draft);
          final result = await _client.rpc('record_crop_harvest', params: {
            'p_entry': {
              'crop_id': cropId,
              'quantity': quantity,
              'unit': 'kg',
              'performed_at': date.toUtc().toIso8601String(),
              'notes': notes,
              'task_id': taskId,
              'next_check_on': entry['next_check_on'],
              'submission_id': id,
            },
          });
          await _removeCareDraft(userId, id);
          return {
            'status': 'Synced',
            'submission_id': id,
            if (result is Map) ...Map<String, dynamic>.from(result),
          };
        }
        await _saveDraft(userId, id, {
          ...entry,
          'status': 'Syncing',
          'harvest_version': 1,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
        await _client.rpc('harvest_crop_batch', params: {
          'p_crop_id': cropId,
          'p_quantity': quantity,
          'p_performed_at': date.toUtc().toIso8601String(),
          'p_notes': notes,
          'p_submission_id': id,
        });
        await _removeCareDraft(userId, id);
        return {
          'status': 'Synced',
          'submission_id': id,
        };
      }
      durablePhotos = await _persistJournalPhotos(userId, id, photoFiles);
      uploadedPhotoPaths =
          await _uploadJournalPhotos(userId, cropId, id, durablePhotos);
      final result = await _client.rpc('record_crop_entry', params: {
        'p_entry': {...entry, 'photos': uploadedPhotoPaths},
      });
      await _deleteDraftPhotoFiles(durablePhotos);
      return {
        'status': 'Synced',
        'activity_id': result.toString(),
        'submission_id': id
      };
    } catch (error) {
      if (_client.auth.currentUser?.id != userId) {
        await _saveDraft(userId, id, {
          ...entry,
          'photo_files': durablePhotos,
          'status': 'Needs review',
          'message':
              'The signed-in account changed before this crop entry could be confirmed. Sign back into the original account to review it.',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
        return {'status': 'Needs review', 'submission_id': id};
      }
      final isConnectionFailure = _looksOffline(error);
      if (!isConnectionFailure) {
        if (activity == CropMaintenanceActivity.harvested) {
          await _removeCareDraft(userId, id);
        }
        if (uploadedPhotoPaths.isNotEmpty) {
          try {
            await _client.storage
                .from('crop-journal')
                .remove(uploadedPhotoPaths);
          } catch (_) {
            // A failed cleanup must not hide the original save error.
          }
        }
        await _deleteDraftPhotoFiles(durablePhotos);
        throw _friendlyWorkflowError(error);
      }
      if (durablePhotos.isEmpty) {
        durablePhotos = await _persistJournalPhotos(userId, id, photoFiles);
      }
      final draft = {
        ...entry,
        'photo_files': durablePhotos,
        'status': 'Saved on device',
        if (activity == CropMaintenanceActivity.harvested) 'harvest_version': 2,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
      await _saveDraft(userId, id, draft);
      return {'status': 'Saved on device', 'submission_id': id};
    }
  }

  Future<List<String>> _persistJournalPhotos(
      String userId, String submissionId, List<String> files) async {
    if (files.isEmpty) return const [];
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(
        '${root.path}${Platform.pathSeparator}crop-care-drafts${Platform.pathSeparator}$userId${Platform.pathSeparator}$submissionId');
    await directory.create(recursive: true);
    final saved = <String>[];
    for (var index = 0; index < files.length; index++) {
      final source = File(files[index]);
      final target =
          File('${directory.path}${Platform.pathSeparator}$index.jpg');
      await source.copy(target.path);
      saved.add(target.path);
    }
    return saved;
  }

  Future<void> _deleteDraftPhotoFiles(List<String> files) async {
    for (final path in files) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<List<String>> _uploadJournalPhotos(String userId, String cropId,
      String submissionId, List<String> files) async {
    if (_client.auth.currentUser?.id != userId) {
      throw StateError(
          'Your account changed. Reopen this crop entry to continue.');
    }
    final paths = <String>[];
    for (var i = 0; i < files.length; i++) {
      final file = File(files[i]);
      final path = '$userId/$cropId/$submissionId-$i.jpg';
      await _client.storage.from('crop-journal').upload(path, file,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: true));
      paths.add(path);
    }
    return paths;
  }

  String _draftKey(String userId) => 'crop-care-drafts:$userId';
  Future<List<Map<String, dynamic>>> getCareDrafts({String? userId}) async {
    final ownerId = userId ?? _client.auth.currentUser?.id;
    if (ownerId == null) return [];
    final prefs = await SharedPreferences.getInstance();
    return (jsonDecode(prefs.getString(_draftKey(ownerId)) ?? '[]')
            as List<dynamic>)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .map((draft) {
      if (draft['status'] == 'Syncing') draft['status'] = 'Saved on device';
      return draft;
    }).toList();
  }

  Future<void> _saveDraft(
      String userId, String id, Map<String, dynamic> draft) async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = await getCareDrafts(userId: userId);
    final index = drafts.indexWhere((v) => v['submission_id'] == id);
    if (index >= 0) {
      drafts[index] = draft;
    } else {
      drafts.add(draft);
    }
    await prefs.setString(_draftKey(userId), jsonEncode(drafts));
  }

  Future<void> _removeCareDraft(String userId, String id) async {
    final preferences = await SharedPreferences.getInstance();
    final drafts = await getCareDrafts(userId: userId);
    drafts.removeWhere((draft) => draft['submission_id'] == id);
    await preferences.setString(_draftKey(userId), jsonEncode(drafts));
  }

  Future<bool> hasPendingCropEntries(String cropId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final drafts = await getCareDrafts(userId: userId);
    return drafts.any((draft) =>
        draft['crop_id'] == cropId &&
        draft['activity_type'] == 'Harvested' &&
        draft['status'] != 'Synced');
  }

  Future<Map<String, dynamic>> endCrop({
    required String cropId,
    required String reason,
    String? explanation,
    required String submissionId,
  }) async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) {
      throw StateError('Sign in before ending this crop.');
    }
    if (await hasPendingCropEntries(cropId)) {
      throw StateError(
          'Sync or resolve this crop\'s saved harvest before ending it.');
    }
    final payload = <String, dynamic>{
      'crop_id': cropId,
      'reason': reason.trim(),
      'explanation':
          explanation?.trim().isEmpty == true ? null : explanation?.trim(),
      'version': 2,
    };
    final prefs = await SharedPreferences.getInstance();
    final key = 'pending_crop_endings_v1:$ownerId';
    final entries = (jsonDecode(prefs.getString(key) ?? '[]') as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final matches = entries.where((row) => row['crop_id'] == cropId);
    final existing = matches.isEmpty ? null : matches.first;
    if (existing != null &&
        jsonEncode(existing['payload']) != jsonEncode(payload)) {
      throw StateError(
          'A previous crop-ending request is unresolved. Retry the same reason and details first.');
    }
    final savedSubmissionId =
        existing?['submission_id'] as String? ?? submissionId;
    if (existing == null) {
      entries.add({
        'crop_id': cropId,
        'submission_id': savedSubmissionId,
        'payload': payload,
        'status': 'Sending',
      });
      await prefs.setString(key, jsonEncode(entries));
    }
    if (_client.auth.currentUser?.id != ownerId) {
      throw StateError('Your account changed. Reopen the crop and try again.');
    }
    try {
      final result = await _client.rpc('end_crop', params: {
        'p_entry': {...payload, 'submission_id': savedSubmissionId},
      });
      if (_client.auth.currentUser?.id != ownerId) {
        throw StateError(
            'This crop ending was sent from the original account. Sign back in there to confirm it.');
      }
      entries.removeWhere((row) => row['submission_id'] == savedSubmissionId);
      await prefs.setString(key, jsonEncode(entries));
      return Map<String, dynamic>.from(result as Map);
    } catch (error) {
      if (_client.auth.currentUser?.id == ownerId && !_looksOffline(error)) {
        entries.removeWhere((row) => row['submission_id'] == savedSubmissionId);
      } else {
        for (final row in entries
            .where((entry) => entry['submission_id'] == savedSubmissionId)) {
          row['status'] = 'Needs review';
        }
      }
      await prefs.setString(key, jsonEncode(entries));
      throw _friendlyWorkflowError(error);
    }
  }

  Future<List<Map<String, dynamic>>> getCropHarvestHistory(
      String cropId) async {
    final response = await _client.rpc('get_crop_harvest_history', params: {
      'p_crop_id': cropId,
      'p_limit': 100,
      'p_offset': 0,
    });
    return (response as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getCropHarvestCorrections(
      String harvestId) async {
    final response = await _client.rpc('get_crop_harvest_corrections', params: {
      'p_harvest_id': harvestId,
    });
    return (response as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  String _harvestCorrectionKey(String ownerId) =>
      'pending_harvest_corrections_v1:$ownerId';

  Future<bool> hasPendingHarvestCorrection(String cropId,
      {String? userId}) async {
    final ownerId = userId ?? _client.auth.currentUser?.id;
    if (ownerId == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final drafts =
        jsonDecode(prefs.getString(_harvestCorrectionKey(ownerId)) ?? '[]')
            as List;
    return drafts.any((entry) =>
        (entry as Map)['crop_id'] == cropId && entry['status'] != 'Confirmed');
  }

  Future<Map<String, dynamic>> correctCropHarvest({
    required String cropId,
    required String harvestId,
    required int expectedRevision,
    required double quantity,
    required String? notes,
    required String reason,
  }) async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) {
      throw StateError('Sign in before correcting a harvest.');
    }
    if (quantity <= 0 ||
        quantity > 9999999999.99 ||
        quantity != double.parse(quantity.toStringAsFixed(2))) {
      throw ArgumentError(
          'Enter a weight greater than zero with up to two decimal places.');
    }
    final normalizedNotes = notes?.trim().replaceAll(RegExp(r'\s+'), ' ');
    final payload = <String, dynamic>{
      'crop_id': cropId,
      'harvest_id': harvestId,
      'expected_revision': expectedRevision,
      'quantity': quantity,
      'notes': normalizedNotes == null || normalizedNotes.isEmpty
          ? null
          : normalizedNotes,
      'reason': reason.trim(),
      'version': 1,
    };
    final prefs = await SharedPreferences.getInstance();
    final key = _harvestCorrectionKey(ownerId);
    final pending = (jsonDecode(prefs.getString(key) ?? '[]') as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final matches = pending.where((row) => row['harvest_id'] == harvestId);
    final existing = matches.isEmpty ? null : matches.first;
    if (existing != null &&
        jsonEncode(existing['payload']) != jsonEncode(payload)) {
      throw StateError(
          'A previous correction is unresolved. Retry those same details first.');
    }
    final submissionId = existing?['submission_id'] as String? ?? _newUuid();
    if (existing == null) {
      pending.add({
        'crop_id': cropId,
        'harvest_id': harvestId,
        'submission_id': submissionId,
        'payload': payload,
        'status': 'Sending',
      });
      await prefs.setString(key, jsonEncode(pending));
    }
    if (_client.auth.currentUser?.id != ownerId) {
      throw StateError(
          'Your account changed. Sign back into the original account to retry.');
    }
    try {
      final response = await _client.rpc('correct_crop_harvest', params: {
        'p_entry': {...payload, 'submission_id': submissionId},
      });
      if (_client.auth.currentUser?.id != ownerId) {
        throw StateError(
            'The original account’s result is saved. Sign back into that account to confirm it.');
      }
      pending.removeWhere((row) => row['submission_id'] == submissionId);
      await prefs.setString(key, jsonEncode(pending));
      return Map<String, dynamic>.from(response as Map);
    } catch (error) {
      if (_client.auth.currentUser?.id == ownerId &&
          error is PostgrestException) {
        pending.removeWhere((row) => row['submission_id'] == submissionId);
      } else {
        for (final row
            in pending.where((row) => row['submission_id'] == submissionId)) {
          row['status'] = 'Needs review';
        }
      }
      await prefs.setString(key, jsonEncode(pending));
      throw _friendlyWorkflowError(error);
    }
  }

  Future<bool> retryCareDraft(String id, {String? ownerId}) async {
    final userId = ownerId ?? _client.auth.currentUser?.id;
    if (userId == null || _client.auth.currentUser?.id != userId) return false;
    final drafts = await getCareDrafts(userId: userId);
    final index = drafts.indexWhere((v) => v['submission_id'] == id);
    if (index < 0) return true;
    final draft = drafts[index];
    draft['status'] = 'Syncing';
    await _saveDraft(userId, id, draft);
    try {
      if (_client.auth.currentUser?.id != userId) return false;
      if (draft['activity_type'] == 'Harvested' &&
          draft['harvest_version'] != 2) {
        final committed = await _client.rpc('get_crop_harvest_submission',
            params: {'p_submission_id': id});
        if (committed != null) {
          await _removeCareDraft(userId, id);
          return true;
        }
        final crop = await _client
            .from('crops')
            .select('harvest_mode')
            .eq('id', draft['crop_id'] as String)
            .single();
        if (crop['harvest_mode'] == 'repeat') {
          draft['status'] = 'Needs review';
          draft['message'] =
              'This saved harvest came from an older app version. Review it before sending so it does not close a repeat-harvest crop unexpectedly.';
          await _saveDraft(userId, id, draft);
          return false;
        }
        if (_client.auth.currentUser?.id != userId) return false;
        await _client.rpc('harvest_crop_batch', params: {
          'p_crop_id': draft['crop_id'],
          'p_quantity': draft['quantity'],
          'p_performed_at': draft['performed_at'],
          'p_notes': draft['notes'],
          'p_submission_id': id,
        });
        await _removeCareDraft(userId, id);
        return true;
      }
      final paths = await _uploadJournalPhotos(
          userId,
          draft['crop_id'] as String,
          id,
          List<String>.from(draft['photo_files'] as List? ?? const []));
      if (_client.auth.currentUser?.id != userId) return false;
      final entry = <String, dynamic>{
        for (final e in draft.entries)
          if (!['status', 'message', 'created_at', 'photo_files']
              .contains(e.key))
            e.key: e.value,
        'photos': paths
      };
      if (entry['activity_type'] == 'Harvested') {
        final crop = await _client
            .from('crops')
            .select('harvest_mode')
            .eq('id', entry['crop_id'] as String)
            .single();
        if (crop['harvest_mode'] == 'repeat') {
          if (_client.auth.currentUser?.id != userId) return false;
          await _client.rpc('record_crop_harvest', params: {
            'p_entry': {
              'crop_id': entry['crop_id'],
              'quantity': entry['quantity'],
              'unit': 'kg',
              'performed_at': entry['performed_at'],
              'notes': entry['notes'],
              'task_id': entry['task_id'],
              'next_check_on': entry['next_check_on'],
              'submission_id': id,
            },
          });
        } else {
          if (_client.auth.currentUser?.id != userId) return false;
          await _client.rpc('harvest_crop_batch', params: {
            'p_crop_id': entry['crop_id'],
            'p_quantity': entry['quantity'],
            'p_performed_at': entry['performed_at'],
            'p_notes': entry['notes'],
            'p_submission_id': id,
          });
        }
      } else {
        if (_client.auth.currentUser?.id != userId) return false;
        await _client.rpc('record_crop_entry', params: {'p_entry': entry});
      }
      await _deleteDraftPhotoFiles(
          List<String>.from(draft['photo_files'] as List? ?? const []));
      drafts.removeAt(index);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftKey(userId), jsonEncode(drafts));
      return true;
    } catch (error) {
      draft['status'] =
          _looksOffline(error) ? 'Saved on device' : 'Needs review';
      draft.remove('message');
      await _saveDraft(userId, id, draft);
      return false;
    }
  }

  Future<int> retryPendingCareDrafts() async {
    var synced = 0;
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) return 0;
    for (final draft in await getCareDrafts(userId: ownerId)) {
      if (draft['status'] == 'Saved on device') {
        if (_client.auth.currentUser?.id != ownerId) break;
        final ok = await retryCareDraft(
          draft['submission_id'] as String,
          ownerId: ownerId,
        );
        if (ok) {
          synced++;
        } else {
          break;
        }
      }
    }
    return synced;
  }

  bool _looksOffline(Object error) {
    final value = error.toString().toLowerCase();
    return value.contains('socketexception') ||
        value.contains('timed out') ||
        value.contains('timeoutexception') ||
        value.contains('connection reset') ||
        value.contains('failed host lookup') ||
        value.contains('network is unreachable') ||
        value.contains('clientexception');
  }

  Object _friendlyWorkflowError(Object error) {
    if (error is PostgrestException &&
        (error.message.contains('schema cache') ||
            error.message.contains('Could not find the function') ||
            error.message.contains('record_crop_harvest') ||
            error.message.contains('correct_crop_harvest'))) {
      return StateError(
          'This crop action needs the latest database update. Ask the system administrator to apply the approved migration, then try again.');
    }
    return error;
  }

  String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<String> signedJournalPhoto(String path) =>
      _client.storage.from('crop-journal').createSignedUrl(path, 3600);

  String newSubmissionId() => _newUuid();

  Future<Map<String, dynamic>> getHarvestDestination(String cropId) async {
    final result = await _client
        .rpc('crop_harvest_destination', params: {'p_crop_id': cropId});
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> renamePlanting({
    required String cropId,
    required String plantingName,
    required int expectedVersion,
    required bool useAssigned,
    required String submissionId,
  }) async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) throw StateError('Sign in to save a planting name.');
    final payload = {
      'crop_id': cropId,
      'planting_name': plantingName,
      'expected_version': expectedVersion,
      'use_assigned': useAssigned,
      'submission_id': submissionId,
    };
    final drafts = await _pendingPlantingNameDrafts();
    drafts.removeWhere((draft) => draft['crop_id'] == cropId);
    drafts.add({...payload, 'owner_id': ownerId, 'status': 'Waiting to sync'});
    await _savePendingPlantingNameDrafts(drafts);
    try {
      final result = await _client
          .rpc('rename_crop_planting', params: {'p_entry': payload});
      await _removePlantingNameDraft(cropId, ownerId);
      return Map<String, dynamic>.from(result as Map);
    } catch (error) {
      final message = error.toString();
      if (message.toLowerCase().contains('changed on another device') ||
          message.toLowerCase().contains('revision')) {
        await _setPlantingNameDraftStatus(cropId, ownerId, 'Needs review');
        return {'status': 'Needs review'};
      }
      if (error is SocketException ||
          error is TimeoutException ||
          message.toLowerCase().contains('network is unreachable') ||
          message.toLowerCase().contains('failed host lookup') ||
          message.toLowerCase().contains('connection refused') ||
          message.toLowerCase().contains('clientexception') ||
          message.toLowerCase().contains('failed to fetch') ||
          message.toLowerCase().contains('timed out')) {
        return {'status': 'Waiting to sync'};
      }
      await _removePlantingNameDraft(cropId, ownerId);
      rethrow;
    }
  }

  Future<int> retryPendingPlantingNames() async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) return 0;
    final drafts = await _pendingPlantingNameDrafts();
    var synced = 0;
    for (final draft
        in drafts.where((value) => value['status'] == 'Waiting to sync')) {
      try {
        await _client.rpc('rename_crop_planting', params: {
          'p_entry': {
            'crop_id': draft['crop_id'],
            'planting_name': draft['planting_name'],
            'expected_version': draft['expected_version'],
            'use_assigned': draft['use_assigned'],
            'submission_id': draft['submission_id'],
          }
        });
        await _removePlantingNameDraft(draft['crop_id'] as String, ownerId);
        synced++;
      } catch (error) {
        if (error
            .toString()
            .toLowerCase()
            .contains('changed on another device')) {
          await _setPlantingNameDraftStatus(
              draft['crop_id'] as String, ownerId, 'Needs review');
        }
      }
    }
    return synced;
  }

  Future<void> discardPendingPlantingName(String cropId) async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) return;
    await _removePlantingNameDraft(cropId, ownerId);
  }

  Future<List<Map<String, dynamic>>> _pendingPlantingNameDrafts() async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) return [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_plantingNameDraftKey(ownerId));
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .where((value) => value['owner_id'] == ownerId)
        .toList();
  }

  Future<void> _savePendingPlantingNameDrafts(
      List<Map<String, dynamic>> drafts) async {
    final ownerId = _client.auth.currentUser?.id;
    if (ownerId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_plantingNameDraftKey(ownerId), jsonEncode(drafts));
  }

  String _plantingNameDraftKey(String ownerId) =>
      '$_plantingNameDraftStoragePrefix$ownerId';

  Future<void> _removePlantingNameDraft(String cropId, String ownerId) async {
    final drafts = await _pendingPlantingNameDrafts();
    drafts.removeWhere((draft) => draft['crop_id'] == cropId);
    await _savePendingPlantingNameDrafts(drafts);
  }

  Future<void> _setPlantingNameDraftStatus(
      String cropId, String ownerId, String status) async {
    final drafts = await _pendingPlantingNameDrafts();
    for (final draft in drafts.where((value) => value['crop_id'] == cropId)) {
      draft['status'] = status;
    }
    await _savePendingPlantingNameDrafts(drafts);
  }

  Map<String, Object?> _cropPayload(CropModel crop) {
    return {
      'crop_name': crop.name,
      'planting_date': _dateOnly(crop.plantingDate),
      'estimated_harvest': _dateOnly(crop.estimatedHarvest),
      'growth_stage': _growthStageToDb(crop.growthStage),
      'crop_status': _statusToDb(crop.status),
      'maintenance_notes': _encodeMaintenanceNotes(crop),
    };
  }

  CropModel _cropFromRow(
    Map<String, dynamic> row,
    CropSensorSnapshot sensors, {
    Map<String, String> seedImages = const {},
    List<CropMaintenanceRecord>? maintenanceHistory,
    List<CropCareTask> tasks = const [],
  }) {
    final cropName = row['crop_name'] as String? ?? 'Crop';
    final plantingDate = _parseDate(row['planting_date']) ?? DateTime.now();
    final estimatedHarvest = _parseDate(row['estimated_harvest']);
    final status = _statusFromDb(row['crop_status'] as String?);
    final growthStage = _growthStageFromDb(row['growth_stage'] as String?);
    final recordedGrowthStage =
        row['growth_stage'] as String? ?? 'Stage unavailable';
    final stagePlan = ((row['crop_profiles']
                as Map<String, dynamic>?)?['stage_plan'] as List<dynamic>? ??
            const [])
        .map((stage) => (stage as Map<String, dynamic>)['stage'] as String)
        .toSet();
    final profileStages = <String>[];
    for (final stage in stagePlan) {
      final normalizedStage =
          stage == 'First Harvest' ? 'Harvest Ready' : stage;
      if (normalizedStage == 'Completed' ||
          normalizedStage == 'Repeated Harvest' ||
          profileStages.contains(normalizedStage)) {
        continue;
      }
      profileStages.add(normalizedStage);
    }
    profileStages.remove('Harvest Ready');
    profileStages.add('Harvest Ready');
    final notes = row['maintenance_notes'] as String?;
    final cropImagePath = row['image_path'] as String?;
    final cropProfileKey = row['crop_profile_key'] as String?;
    final imagePath = cropImagePath ?? seedImages[cropProfileKey ?? ''];
    final hasLocalStageImage =
        (cropImagePath == null || cropImagePath.trim().isEmpty) &&
            const {'sitaw', 'calamansi', 'peanut'}
                .contains((cropProfileKey ?? cropName).trim().toLowerCase());
    final manager = row['profiles'] as Map<String, dynamic>?;
    final harvestedAt = _parseDateTime(row['harvested_at']);

    return CropModel(
      id: row['id'] as String,
      batchCode: row['batch_code'] as String? ?? '',
      name: cropName,
      variety: 'Not recorded',
      location: row['planting_field_label'] as String? ??
          row['field_label'] as String? ??
          'Field not labeled',
      plantingDate: plantingDate,
      estimatedHarvest: estimatedHarvest,
      growthStage: growthStage,
      status: status,
      maintenanceNotes: _maintenanceNotesFrom(notes),
      managerName: manager?['full_name'] as String? ?? 'Unassigned',
      sensorSnapshot: sensors,
      maintenanceHistory: maintenanceHistory ?? const [],
      reminders: _remindersFor(status, estimatedHarvest),
      notes: notes?.trim() ?? '',
      imagePath: imagePath,
      imageUrl: hasLocalStageImage ? null : _publicCropImageUrl(imagePath),
      harvestDate: harvestedAt,
      lastWateredAt: _parseDateTime(row['last_watered_at']),
      plantingSource: row['planting_source'] as String? ?? 'Legacy',
      fieldLabel: row['field_label'] as String? ?? 'Field not labeled',
      fieldAreaM2: (row['field_area_m2'] as num?)?.toDouble(),
      harvestWindowStart: _parseDate(row['harvest_window_start']),
      harvestWindowEnd: _parseDate(row['harvest_window_end']),
      forecastConfidence: estimatedHarvest == null
          ? 'Unavailable'
          : row['forecast_confidence'] as String? ?? 'Low',
      expectedStage: estimatedHarvest == null
          ? 'Not estimated'
          : row['expected_stage'] as String? ?? 'Milestone unavailable',
      careStatus:
          row['current_care_status'] as String? ?? 'Review crop condition',
      propagationMethod: row['propagation_method'] as String? ?? 'Unknown',
      recordedGrowthStage: recordedGrowthStage == 'First Harvest'
          ? 'Harvest Ready'
          : recordedGrowthStage,
      assignedManagerId: row['assigned_manager'] as String?,
      cropProfileKey: row['crop_profile_key'] as String?,
      harvestMode: row['harvest_mode'] as String? ??
          (const ['sitaw', 'calamansi']
                  .contains((row['crop_profile_key'] as String?)?.toLowerCase())
              ? 'repeat'
              : 'single'),
      harvestCount: ((row['harvest_summary'] as Map?)?['harvest_count'] as num?)
              ?.toInt() ??
          0,
      harvestedQuantity:
          ((row['harvest_summary'] as Map?)?['total_quantity'] as num?)
              ?.toDouble(),
      profileStages: profileStages,
      careTasks: tasks,
      plantingTargetDrops: (row['planting_target_drops'] as num?)?.toInt(),
      plantingCompletedDrops:
          (row['planting_completed_drops'] as num?)?.toInt(),
      assignedPlantingName: row['assigned_planting_name'] as String?,
      customPlantingName: row['custom_planting_name'] as String?,
      plantingNameVersion: (row['planting_name_version'] as num?)?.toInt() ?? 0,
    );
  }

  String? _publicCropImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return null;
    }

    return _client.storage.from(_cropImagesBucket).getPublicUrl(imagePath);
  }

  Future<List<CropMaintenanceRecord>> _activityHistory(String cropId) async =>
      (await _activityHistories([cropId]))[cropId] ?? const [];

  Future<List<CropMaintenanceRecord>> getActivityHistory(String cropId) {
    if (cropId.trim().isEmpty) {
      throw ArgumentError.value(cropId, 'cropId', 'Crop record is required.');
    }
    return _activityHistory(cropId);
  }

  Future<Map<String, List<CropMaintenanceRecord>>> _activityHistories(
    List<String> cropIds,
  ) async {
    final histories = <String, List<CropMaintenanceRecord>>{
      for (final id in cropIds) id: <CropMaintenanceRecord>[],
    };
    if (cropIds.isEmpty) return histories;

    const pageSize = 500;
    final rows = <dynamic>[];
    Future<List<dynamic>> loadPage(int offset,
        {required bool withPhotos}) async {
      final columns = withPhotos
          ? 'id, crop_id, activity_type, performed_at, quantity, unit, material, notes, observed_stage, source, performed_by, crop_activity_photos(path)'
          : 'id, crop_id, activity_type, performed_at, quantity, unit, material, notes, observed_stage, source, performed_by';
      return await _client
          .from('crop_activities')
          .select(columns)
          .inFilter('crop_id', cropIds)
          .order('performed_at', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + pageSize - 1) as List<dynamic>;
    }

    var offset = 0;
    while (true) {
      late final List<dynamic> page;
      try {
        page = await loadPage(offset, withPhotos: true);
      } catch (_) {
        page = await loadPage(offset, withPhotos: false);
      }
      rows.addAll(page);
      if (page.length < pageSize) break;
      offset += pageSize;
    }

    final performerIds = rows
        .map((value) => (value as Map<String, dynamic>)['performed_by'])
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    final performerNames = <String, String>{};
    if (performerIds.isNotEmpty) {
      try {
        final profiles = await _client.rpc(
          'crop_performer_names',
          params: {'p_performer_ids': performerIds},
        ) as List<dynamic>;
        for (final value in profiles) {
          final profile = value as Map<String, dynamic>;
          final id = profile['performer_id'] as String?;
          final fullName = (profile['full_name'] as String?)?.trim();
          if (id != null && fullName?.isNotEmpty == true) {
            performerNames[id] = fullName!;
          }
        }
      } catch (_) {
        // Keep activity history visible even when a profile is no longer readable.
      }
    }

    for (final value in rows) {
      final row = value as Map<String, dynamic>;
      final cropId = row['crop_id'] as String?;
      if (cropId == null || !histories.containsKey(cropId)) continue;
      final source = row['source'] as String? ?? 'User';
      final attachments =
          row['crop_activity_photos'] as List<dynamic>? ?? const [];
      final performedById = row['performed_by'] as String?;

      histories[cropId]!.add(CropMaintenanceRecord(
        activity: _maintenanceActivityFromDb(row['activity_type'] as String?),
        performedAt: _parseDateTime(row['performed_at']) ?? DateTime.now(),
        notes: (row['notes'] as String?)?.trim().isNotEmpty == true
            ? (row['notes'] as String).trim()
            : 'No notes were added.',
        performedBy:
            (performedById == null ? null : performerNames[performedById]) ??
                (source == 'Rover' ? 'SeedRover' : 'Former user'),
        quantity: (row['quantity'] as num?)?.toDouble(),
        unit: row['unit'] as String?,
        material: row['material'] as String?,
        observedStage: switch (row['observed_stage'] as String?) {
          'First Harvest' => 'Harvest Ready',
          final stage => stage,
        },
        source: source,
        id: row['id'] as String?,
        photoPaths: attachments
            .map((photo) => (photo as Map<String, dynamic>)['path'] as String)
            .toList(),
      ));
    }
    return histories;
  }

  CropMaintenanceActivity _maintenanceActivityFromDb(String? value) {
    return switch (value) {
      'Planted' => CropMaintenanceActivity.planted,
      'Watered' => CropMaintenanceActivity.watered,
      'Fertilized' => CropMaintenanceActivity.fertilized,
      'Stage Observed' => CropMaintenanceActivity.stageObserved,
      'Transplanted' => CropMaintenanceActivity.transplanted,
      'Harvested' => CropMaintenanceActivity.harvested,
      'Not Harvested' => CropMaintenanceActivity.notHarvested,
      'Planting Failed' => CropMaintenanceActivity.plantingFailed,
      _ => CropMaintenanceActivity.inspected,
    };
  }

  Future<CropSensorSnapshot> _latestSensorSnapshot({String? cropId}) async {
    var query = _client.from(DatabaseTables.sensorReadings).select(
          'soil_raw, soil_moisture, soil_temperature, environmental_temperature, humidity, calibrated_value, recorded_at, source, provenance_status, soil_moisture_calibrated, calibration_version',
        );
    if (cropId != null) query = query.eq('crop_id', cropId);
    final now = DateTime.now();
    final rows = await query
        .eq('provenance_status', 'verified_hardware')
        .gte('recorded_at',
            now.subtract(const Duration(seconds: 60)).toUtc().toIso8601String())
        .lte('recorded_at', now.toUtc().toIso8601String())
        .order('recorded_at', ascending: false)
        .limit(1) as List<dynamic>;

    if (rows.isEmpty) return _emptySensorSnapshot();
    return _sensorSnapshotFromRow(rows.first as Map<String, dynamic>);
  }

  Future<Map<String, CropSensorSnapshot>> _latestSensorSnapshots(
    List<String> cropIds,
  ) async {
    final snapshots = <String, CropSensorSnapshot>{};
    if (cropIds.isEmpty) return snapshots;
    final now = DateTime.now();
    const pageSize = 500;
    var offset = 0;
    while (snapshots.length < cropIds.length) {
      final rows = await _client
          .from(DatabaseTables.sensorReadings)
          .select(
            'crop_id, soil_raw, soil_moisture, soil_temperature, environmental_temperature, humidity, calibrated_value, recorded_at, source, provenance_status, soil_moisture_calibrated, calibration_version',
          )
          .inFilter('crop_id', cropIds)
          .eq('provenance_status', 'verified_hardware')
          .gte(
              'recorded_at',
              now
                  .subtract(const Duration(seconds: 60))
                  .toUtc()
                  .toIso8601String())
          .lte('recorded_at', now.toUtc().toIso8601String())
          .order('recorded_at', ascending: false)
          .range(offset, offset + pageSize - 1) as List<dynamic>;
      for (final value in rows) {
        final row = value as Map<String, dynamic>;
        final cropId = row['crop_id'] as String?;
        if (cropId != null && !snapshots.containsKey(cropId)) {
          snapshots[cropId] = _sensorSnapshotFromRow(row);
        }
      }
      if (rows.length < pageSize) break;
      offset += pageSize;
    }
    return snapshots;
  }

  CropSensorSnapshot _sensorSnapshotFromRow(Map<String, dynamic> row) =>
      CropSensorSnapshot(
        soilMoisture: row['soil_moisture_calibrated'] == true &&
                row['calibration_version'] != null
            ? _sensorNumber(
                row['calibrated_value'] ?? row['soil_moisture'], 0, 100)
            : null,
        soilRaw: _sensorNumber(row['soil_raw'], 1, 4094)?.toInt(),
        soilTemperature: _sensorNumber(row['soil_temperature'], -55, 125),
        environmentTemperature:
            _sensorNumber(row['environmental_temperature'], -40, 80),
        humidity: _sensorNumber(row['humidity'], 0, 100),
        recordedAt: _parseDateTime(row['recorded_at']),
        source: row['source']?.toString(),
        provenanceStatus: row['provenance_status']?.toString(),
        soilMoistureCalibrated: row['soil_moisture_calibrated'] == false
            ? false
            : row['soil_moisture_calibrated'] == true &&
                    row['calibration_version'] != null
                ? true
                : null,
        calibrationVersion: row['calibration_version']?.toString(),
      );

  CropSensorSnapshot _emptySensorSnapshot() => const CropSensorSnapshot(
        soilMoisture: null,
        soilRaw: null,
        soilTemperature: null,
        environmentTemperature: null,
        humidity: null,
      );

  Future<void> _recordActivity({
    required String activity,
    required String description,
  }) async {
    final userId = _client.auth.currentUser?.id;

    try {
      await _client.from(DatabaseTables.activityLogs).insert({
        'user_id': userId,
        'activity': activity,
        'description': description,
        'module': 'Crops',
      });
    } catch (_) {
      // Activity logging should not block the crop action itself.
    }
  }

  String _encodeMaintenanceNotes(CropModel crop) {
    if (crop.maintenanceNotes.isEmpty) {
      return crop.notes;
    }

    return crop.maintenanceNotes.join('\n');
  }

  List<String> _maintenanceNotesFrom(String? value) {
    final notes = value
        ?.split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (notes == null || notes.isEmpty) return const [];

    return notes;
  }

  List<String> _remindersFor(CropStatus status, DateTime? harvestDate) {
    return switch (status) {
      CropStatus.readyForHarvest => const ['Prepare harvest check.'],
      CropStatus.harvested => const ['Crop cycle completed.'],
      CropStatus.notHarvested => const ['Ended without a harvest.'],
      CropStatus.active => const ['No care tasks due.'],
      CropStatus.needsAttention => const ['Care tasks need attention.'],
    };
  }

  CropGrowthStage _growthStageFromDb(String? value) {
    return switch (value) {
      'Seeded' => CropGrowthStage.seeded,
      'Seedbed' => CropGrowthStage.seedbed,
      'Germinating' => CropGrowthStage.germinating,
      'Nursery Seedling' => CropGrowthStage.nurserySeedling,
      'Transplant Review' => CropGrowthStage.transplantReview,
      'Establishing' => CropGrowthStage.establishing,
      'Juvenile' => CropGrowthStage.juvenile,
      'Vegetative' => CropGrowthStage.vegetative,
      'Trellising' => CropGrowthStage.trellising,
      'Flowering' => CropGrowthStage.flowering,
      'Pod Formation' => CropGrowthStage.podFormation,
      'Pegging' => CropGrowthStage.pegging,
      'Pod Development' => CropGrowthStage.podDevelopment,
      'Maturity Check' => CropGrowthStage.maturityCheck,
      'First Bearing' => CropGrowthStage.firstBearing,
      'First Harvest' => CropGrowthStage.harvestReady,
      'Fruiting' => CropGrowthStage.fruiting,
      'Harvest Ready' => CropGrowthStage.harvestReady,
      'Completed' => CropGrowthStage.harvested,
      _ => CropGrowthStage.other,
    };
  }

  String _growthStageToDb(CropGrowthStage stage) {
    return switch (stage) {
      CropGrowthStage.seeded => 'Seeded',
      CropGrowthStage.germinating => 'Germinating',
      CropGrowthStage.vegetative => 'Vegetative',
      CropGrowthStage.flowering => 'Flowering',
      CropGrowthStage.fruiting => 'Fruiting',
      CropGrowthStage.seedbed => 'Seedbed',
      CropGrowthStage.nurserySeedling => 'Nursery Seedling',
      CropGrowthStage.transplantReview => 'Transplant Review',
      CropGrowthStage.establishing => 'Establishing',
      CropGrowthStage.juvenile => 'Juvenile',
      CropGrowthStage.trellising => 'Trellising',
      CropGrowthStage.podFormation => 'Pod Formation',
      CropGrowthStage.pegging => 'Pegging',
      CropGrowthStage.podDevelopment => 'Pod Development',
      CropGrowthStage.maturityCheck => 'Maturity Check',
      CropGrowthStage.firstBearing => 'First Bearing',
      CropGrowthStage.harvestReady => 'Harvest Ready',
      CropGrowthStage.harvested => 'Completed',
      CropGrowthStage.other => 'Review stage',
    };
  }

  CropStatus _statusFromDb(String? value) {
    return switch (value) {
      'Needs Attention' => CropStatus.needsAttention,
      'Harvest Ready' => CropStatus.readyForHarvest,
      'Completed' => CropStatus.harvested,
      'Cancelled' => CropStatus.notHarvested,
      'Active' => CropStatus.active,
      _ => CropStatus.active,
    };
  }

  String _statusToDb(CropStatus status) {
    return switch (status) {
      CropStatus.active => 'Active',
      CropStatus.needsAttention => 'Needs Attention',
      CropStatus.readyForHarvest => 'Harvest Ready',
      CropStatus.harvested => 'Completed',
      CropStatus.notHarvested => 'Cancelled',
    };
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }

  DateTime? _parseDateTime(Object? value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String? _dateOnly(DateTime? date) {
    if (date == null) return null;
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  double? _nullableDouble(Object? value) => (value as num?)?.toDouble();

  double? _positiveNumber(Object? value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    return parsed != null && parsed.isFinite && parsed > 0 ? parsed : null;
  }

  double? _litersToMilliliters(Object? value) {
    final liters = _positiveNumber(value);
    return liters == null ? null : liters * 1000;
  }

  double? _sensorNumber(Object? value, double minimum, double maximum) {
    final number = _nullableDouble(value);
    return number != null &&
            number.isFinite &&
            number >= minimum &&
            number <= maximum
        ? number
        : null;
  }
}

final cropRepositoryProvider = Provider<CropRepository>(
  (ref) => CropRepository(
    ref.watch(supabaseClientProvider),
    webAdminUrl: ref.watch(appEnvironmentProvider).webAdminUrl,
  ),
);
