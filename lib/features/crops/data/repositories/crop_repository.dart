import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/database_tables.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/crop_model.dart';

class CropRepository {
  const CropRepository(this._client);

  static const _cropImagesBucket = 'crop-images';

  final SupabaseClient _client;

  Stream<List<CropModel>> watchCrops() {
    return _client
        .from(DatabaseTables.crops)
        .stream(primaryKey: ['id'])
        .order('planting_date')
        .asyncMap((_) => getCrops());
  }

  Future<CropWeatherSnapshot> getWeatherStatus() async {
    final weatherRows = await _client
        .from('weather_forecasts')
        .select(
          'provider, precipitation_probability, temperature_c, humidity_percent, condition, raw_payload, fetched_at',
        )
        .order('fetched_at', ascending: false)
        .limit(2) as List<dynamic>;
    Map<String, dynamic>? openMeteo;
    for (final value in weatherRows) {
      final row = value as Map<String, dynamic>;
      if (row['provider'] == 'Open-Meteo') openMeteo ??= row;
    }
    final raw = openMeteo?['raw_payload'] as Map<String, dynamic>?;
    final summary = raw?['summary'] as Map<String, dynamic>?;
    return CropWeatherSnapshot(
      currentCondition:
          openMeteo?['condition'] as String? ?? 'Weather unavailable',
      nextRainAt: _parseDateTime(summary?['nextRainAt']),
      temperatureC: (openMeteo?['temperature_c'] as num?)?.toDouble(),
      humidityPercent: (openMeteo?['humidity_percent'] as num?)?.toDouble(),
      rainChancePercent:
          (openMeteo?['precipitation_probability'] as num?)?.toDouble(),
      fetchedAt: _parseDateTime(openMeteo?['fetched_at']),
    );
  }

  Future<List<CropModel>> getCrops() async {
    final rows = await _client
        .from(DatabaseTables.crops)
        .select(
          'id, batch_code, crop_name, assigned_manager, planting_date, estimated_harvest, '
          'growth_stage, maintenance_notes, image_path, crop_status, created_at, '
          'updated_at, planting_source, field_label, field_area_m2, completed_drop_cycles, '
          'estimated_seed_count_min, estimated_seed_count_max, harvest_window_start, '
          'harvest_window_end, forecast_confidence, expected_stage, current_care_status, '
          'propagation_method, last_watered_at, profiles(full_name)',
        )
        .order('planting_date', ascending: false) as List<dynamic>;
    return Future.wait(
      rows.map((row) async {
        final cropRow = row as Map<String, dynamic>;
        final cropId = cropRow['id'] as String;
        return _cropFromRow(
          cropRow,
          await _latestSensorSnapshot(cropId: cropId),
          maintenanceHistory: await _activityHistory(cropId),
        );
      }),
    );
  }

  Future<CropModel> createCrop(CropModel crop) async {
    final row = await _client
        .from(DatabaseTables.crops)
        .insert({
          ..._cropPayload(crop),
          'assigned_manager': _client.auth.currentUser?.id,
        })
        .select(
          'id, batch_code, crop_name, assigned_manager, planting_date, estimated_harvest, '
          'growth_stage, maintenance_notes, image_path, crop_status, created_at, '
          'updated_at, planting_source, field_label, field_area_m2, completed_drop_cycles, '
          'estimated_seed_count_min, estimated_seed_count_max, harvest_window_start, '
          'harvest_window_end, forecast_confidence, expected_stage, current_care_status, '
          'propagation_method, last_watered_at, profiles(full_name)',
        )
        .single();

    await _recordActivity(
      activity: 'Crop record created',
      description: '${crop.name} crop record created.',
    );

    final cropId = row['id'] as String;
    return _cropFromRow(
      row,
      await _latestSensorSnapshot(cropId: cropId),
      maintenanceHistory: await _activityHistory(cropId),
    );
  }

  Future<CropModel> createManualCrop({
    required String profileKey,
    required String fieldLabel,
    required double fieldAreaM2,
    required DateTime plantingDate,
    required String reason,
  }) async {
    final names = {
      'calamansi': 'Calamansi',
      'sitaw': 'Sitaw',
      'peanut': 'Peanut'
    };
    final harvestDays = {'sitaw': 60, 'peanut': 95};
    final name = names[profileKey] ?? profileKey;
    final harvest = harvestDays[profileKey] == null
        ? null
        : plantingDate.add(Duration(days: harvestDays[profileKey]!));
    final row = await _client
        .from(DatabaseTables.crops)
        .insert({
          'crop_name': name,
          'assigned_manager': _client.auth.currentUser?.id,
          'planting_date': _dateOnly(plantingDate),
          'estimated_harvest': harvest == null ? null : _dateOnly(harvest),
          'growth_stage': 'Seeded',
          'crop_status': 'Active',
          'planting_source': 'Manual',
          'manual_creation_reason': reason.trim(),
          'crop_profile_key': profileKey,
          'profile_version': 1,
          'field_label': fieldLabel.trim(),
          'field_area_m2': fieldAreaM2,
          'propagation_method': profileKey == 'calamansi'
              ? 'Direct seed to nursery'
              : 'Direct seed',
          'harvest_window_start': harvest == null ? null : _dateOnly(harvest),
          'harvest_window_end': harvest == null
              ? null
              : _dateOnly(
                  harvest.add(Duration(days: profileKey == 'sitaw' ? 10 : 5))),
          'forecast_confidence': 'Low',
          'expected_stage': profileKey == 'calamansi'
              ? 'Germination and nursery review'
              : 'Germination',
          'current_care_status': 'Manual planting - verify field conditions',
        })
        .select(
          'id, batch_code, crop_name, assigned_manager, planting_date, estimated_harvest, growth_stage, maintenance_notes, image_path, crop_status, created_at, updated_at, planting_source, field_label, field_area_m2, completed_drop_cycles, estimated_seed_count_min, estimated_seed_count_max, harvest_window_start, harvest_window_end, forecast_confidence, expected_stage, current_care_status, propagation_method, last_watered_at, profiles(full_name)',
        )
        .single();
    final cropId = row['id'] as String;
    return _cropFromRow(
      row,
      await _latestSensorSnapshot(cropId: cropId),
      maintenanceHistory: await _activityHistory(cropId),
    );
  }

  Future<CropModel> updateCrop(CropModel crop) async {
    final row = await _client
        .from(DatabaseTables.crops)
        .update(_cropPayload(crop))
        .eq('id', crop.id)
        .select(
          'id, batch_code, crop_name, assigned_manager, planting_date, estimated_harvest, '
          'growth_stage, maintenance_notes, image_path, crop_status, created_at, '
          'updated_at, planting_source, field_label, field_area_m2, completed_drop_cycles, '
          'estimated_seed_count_min, estimated_seed_count_max, harvest_window_start, '
          'harvest_window_end, forecast_confidence, expected_stage, current_care_status, '
          'propagation_method, last_watered_at, profiles(full_name)',
        )
        .single();

    await _recordActivity(
      activity: 'Crop record updated',
      description: '${crop.name} crop record updated.',
    );

    return _cropFromRow(
      row,
      await _latestSensorSnapshot(cropId: crop.id),
      maintenanceHistory: await _activityHistory(crop.id),
    );
  }

  Future<void> deleteCrop(String cropId) async {
    await _client.from(DatabaseTables.crops).delete().eq('id', cropId);
    await _recordActivity(
      activity: 'Crop record deleted',
      description: 'Crop record deleted.',
    );
  }

  Future<CropModel> recordMaintenance({
    required CropModel crop,
    required CropMaintenanceActivity activity,
    required DateTime date,
    required String notes,
    CropStatus? status,
    CropGrowthStage? growthStage,
    double? progress,
    DateTime? harvestDate,
    DateTime? lastWateredAt,
    double? quantity,
    String? unit,
    String? material,
    String? observedStage,
  }) async {
    final activityType = switch (activity) {
      CropMaintenanceActivity.planted => 'Stage Observed',
      CropMaintenanceActivity.watered => 'Watered',
      CropMaintenanceActivity.fertilized => 'Fertilized',
      CropMaintenanceActivity.inspected => 'Inspected',
      CropMaintenanceActivity.stageObserved => 'Stage Observed',
      CropMaintenanceActivity.transplanted => 'Transplanted',
      CropMaintenanceActivity.harvested => 'Harvested',
      CropMaintenanceActivity.notHarvested => 'Not Harvested',
      CropMaintenanceActivity.plantingFailed => 'Planting Failed',
    };
    await _client.rpc('record_crop_activity', params: {
      'p_crop_id': crop.id,
      'p_activity_type': activityType,
      'p_performed_at': date.toUtc().toIso8601String(),
      'p_quantity': quantity,
      'p_unit': unit,
      'p_material': material,
      'p_notes': notes,
      'p_observed_stage': observedStage,
      'p_task_id': null,
      'p_idempotency_key':
          'mobile:${crop.id}:${date.microsecondsSinceEpoch}:$activityType',
    });
    final row = await _client
        .from(DatabaseTables.crops)
        .select(
          'id, batch_code, crop_name, assigned_manager, planting_date, estimated_harvest, growth_stage, maintenance_notes, image_path, crop_status, created_at, updated_at, planting_source, field_label, field_area_m2, completed_drop_cycles, estimated_seed_count_min, estimated_seed_count_max, harvest_window_start, harvest_window_end, forecast_confidence, expected_stage, current_care_status, propagation_method, last_watered_at, profiles(full_name)',
        )
        .eq('id', crop.id)
        .single();
    final updatedCrop = _cropFromRow(
      row,
      await _latestSensorSnapshot(cropId: crop.id),
      maintenanceHistory: await _activityHistory(crop.id),
    );

    return updatedCrop.copyWith(
      status: status,
      growthStage: growthStage,
      progress: progress,
      lastWateredAt: lastWateredAt ?? updatedCrop.lastWateredAt,
      harvestDate: harvestDate ?? updatedCrop.harvestDate,
    );
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
    List<CropMaintenanceRecord>? maintenanceHistory,
  }) {
    final cropName = row['crop_name'] as String? ?? 'Crop';
    final plantingDate = _parseDate(row['planting_date']) ?? DateTime.now();
    final estimatedHarvest = _parseDate(row['estimated_harvest']) ??
        plantingDate.add(const Duration(days: 75));
    final status = _statusFromDb(row['crop_status'] as String?);
    final growthStage = _growthStageFromDb(row['growth_stage'] as String?);
    final notes = row['maintenance_notes'] as String?;
    final imagePath = row['image_path'] as String?;
    final manager = row['profiles'] as Map<String, dynamic>?;
    final updatedAt = _parseDateTime(row['updated_at']) ?? DateTime.now();

    return CropModel(
      id: row['id'] as String,
      batchCode: row['batch_code'] as String? ?? '',
      name: cropName,
      variety: _varietyFor(cropName),
      location: row['field_label'] as String? ?? 'Field not labeled',
      plantingDate: plantingDate,
      estimatedHarvest: estimatedHarvest,
      growthStage: growthStage,
      status: status,
      maintenanceNotes: _maintenanceNotesFrom(notes),
      managerName: manager?['full_name'] as String? ?? 'Unassigned',
      progress: _progressFor(growthStage, status),
      sensorSnapshot: sensors,
      maintenanceHistory: maintenanceHistory ?? [
        CropMaintenanceRecord(
          activity: CropMaintenanceActivity.planted,
          performedAt: plantingDate,
          notes: 'Crop record loaded from Supabase.',
          performedBy: 'SeedRover',
        ),
      ],
      reminders: _remindersFor(status, estimatedHarvest),
      notes: notes?.trim().isNotEmpty == true
          ? notes!.trim()
          : '$cropName crop record loaded from Supabase.',
      imagePath: imagePath,
      imageUrl: _publicCropImageUrl(imagePath),
      seedCount: null,
      harvestDate: status == CropStatus.harvested ? updatedAt : null,
      lastWateredAt: _parseDateTime(row['last_watered_at']),
      plantingSource: row['planting_source'] as String? ?? 'Legacy',
      fieldLabel: row['field_label'] as String? ?? 'Field not labeled',
      fieldAreaM2: (row['field_area_m2'] as num?)?.toDouble(),
      completedDrops: (row['completed_drop_cycles'] as num?)?.toInt() ?? 0,
      estimatedSeedMin: (row['estimated_seed_count_min'] as num?)?.toInt(),
      estimatedSeedMax: (row['estimated_seed_count_max'] as num?)?.toInt(),
      harvestWindowStart: _parseDate(row['harvest_window_start']),
      harvestWindowEnd: _parseDate(row['harvest_window_end']),
      forecastConfidence: row['forecast_confidence'] as String? ?? 'Low',
      expectedStage: row['expected_stage'] as String? ?? growthStage.label,
      careStatus:
          row['current_care_status'] as String? ?? 'Review crop condition',
      propagationMethod: row['propagation_method'] as String? ?? 'Unknown',
    );
  }

  String? _publicCropImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return null;
    }

    return _client.storage.from(_cropImagesBucket).getPublicUrl(imagePath);
  }

  Future<List<CropMaintenanceRecord>> _activityHistory(String cropId) async {
    final rows = await _client
        .from('crop_activities')
        .select(
          'activity_type, performed_at, quantity, unit, material, notes, observed_stage, source, performer:profiles!crop_activities_performed_by_fkey(full_name)',
        )
        .eq('crop_id', cropId)
        .order('performed_at', ascending: false) as List<dynamic>;

    return rows.map((value) {
      final row = value as Map<String, dynamic>;
      final performerValue = row['performer'];
      Map<String, dynamic>? performer;
      if (performerValue is Map<String, dynamic>) {
        performer = performerValue;
      } else if (performerValue is List && performerValue.isNotEmpty) {
        performer = performerValue.first as Map<String, dynamic>?;
      }
      final source = row['source'] as String? ?? 'User';

      return CropMaintenanceRecord(
        activity: _maintenanceActivityFromDb(row['activity_type'] as String?),
        performedAt: _parseDateTime(row['performed_at']) ?? DateTime.now(),
        notes: (row['notes'] as String?)?.trim().isNotEmpty == true
            ? (row['notes'] as String).trim()
            : 'No notes were added.',
        performedBy: performer?['full_name'] as String? ??
            (source == 'Rover' ? 'SeedRover' : 'Unknown user'),
        quantity: (row['quantity'] as num?)?.toDouble(),
        unit: row['unit'] as String?,
        material: row['material'] as String?,
        observedStage: row['observed_stage'] as String?,
        source: source,
      );
    }).toList();
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
          'soil_moisture, soil_temperature, environmental_temperature, humidity, calibrated_value, recorded_at',
        );
    if (cropId != null) query = query.eq('crop_id', cropId);
    final rows = await query.order('recorded_at', ascending: false).limit(1)
        as List<dynamic>;

    if (rows.isEmpty) {
      return const CropSensorSnapshot(
        soilMoisture: 0,
        soilTemperature: 0,
        environmentTemperature: 0,
        humidity: 0,
      );
    }

    final row = rows.first as Map<String, dynamic>;

    return CropSensorSnapshot(
      soilMoisture: _toDouble(row['calibrated_value'] ?? row['soil_moisture']),
      soilTemperature: _toDouble(row['soil_temperature']),
      environmentTemperature: _toDouble(row['environmental_temperature']),
      humidity: _toDouble(row['humidity']),
      recordedAt: _parseDateTime(row['recorded_at']),
    );
  }

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

    if (notes == null || notes.isEmpty) {
      return const ['Monitor crop condition during routine field checks.'];
    }

    return notes;
  }

  List<String> _remindersFor(CropStatus status, DateTime harvestDate) {
    return switch (status) {
      CropStatus.needsWater => const ['Watering is due.'],
      CropStatus.needsFertilizer => const ['Fertilizer review is due.'],
      CropStatus.readyForHarvest => const ['Prepare harvest check.'],
      CropStatus.harvested => const ['Crop cycle completed.'],
      CropStatus.healthy => [
          'Estimated harvest: ${_dateOnly(harvestDate)}.',
        ],
    };
  }

  String _varietyFor(String cropName) {
    final name = cropName.toLowerCase();

    if (name.contains('sitaw')) {
      return 'Pole Bean';
    }

    if (name.contains('peanut')) {
      return 'Native Peanut';
    }

    if (name.contains('calamansi')) {
      return 'Seedling Batch';
    }

    return 'Farm Crop';
  }

  double _progressFor(CropGrowthStage stage, CropStatus status) {
    if (status == CropStatus.harvested) {
      return 1;
    }

    return switch (stage) {
      CropGrowthStage.seeded => 0.12,
      CropGrowthStage.germinating => 0.24,
      CropGrowthStage.vegetative => 0.46,
      CropGrowthStage.flowering => 0.66,
      CropGrowthStage.fruiting => 0.82,
      CropGrowthStage.harvestReady => 0.94,
      CropGrowthStage.harvested => 1,
    };
  }

  CropGrowthStage _growthStageFromDb(String? value) {
    return switch (value) {
      'Seeded' => CropGrowthStage.seeded,
      'Germinating' => CropGrowthStage.germinating,
      'Vegetative' => CropGrowthStage.vegetative,
      'Flowering' => CropGrowthStage.flowering,
      'Harvest Ready' => CropGrowthStage.harvestReady,
      'Completed' => CropGrowthStage.harvested,
      _ => CropGrowthStage.seeded,
    };
  }

  String _growthStageToDb(CropGrowthStage stage) {
    return switch (stage) {
      CropGrowthStage.seeded => 'Seeded',
      CropGrowthStage.germinating => 'Germinating',
      CropGrowthStage.vegetative => 'Vegetative',
      CropGrowthStage.flowering => 'Flowering',
      CropGrowthStage.fruiting => 'Flowering',
      CropGrowthStage.harvestReady => 'Harvest Ready',
      CropGrowthStage.harvested => 'Completed',
    };
  }

  CropStatus _statusFromDb(String? value) {
    return switch (value) {
      'Needs Attention' => CropStatus.needsWater,
      'Harvest Ready' => CropStatus.readyForHarvest,
      'Completed' => CropStatus.harvested,
      'Cancelled' => CropStatus.harvested,
      _ => CropStatus.healthy,
    };
  }

  String _statusToDb(CropStatus status) {
    return switch (status) {
      CropStatus.healthy => 'Active',
      CropStatus.needsWater => 'Needs Attention',
      CropStatus.needsFertilizer => 'Needs Attention',
      CropStatus.readyForHarvest => 'Harvest Ready',
      CropStatus.harvested => 'Completed',
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

  String _dateOnly(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  double _toDouble(Object? value) {
    return (value as num?)?.toDouble() ?? 0;
  }
}

final cropRepositoryProvider = Provider<CropRepository>(
  (ref) => CropRepository(ref.watch(supabaseClientProvider)),
);
