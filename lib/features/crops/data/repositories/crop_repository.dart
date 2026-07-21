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

  Future<List<CropModel>> getCrops() async {
    final rows = await _client
        .from(DatabaseTables.crops)
        .select(
          'id, crop_name, assigned_manager, planting_date, estimated_harvest, '
          'growth_stage, maintenance_notes, image_path, crop_status, created_at, '
          'updated_at, profiles(full_name)',
        )
        .order('planting_date', ascending: false) as List<dynamic>;
    final sensors = await _latestSensorSnapshot();

    return rows
        .map((row) => _cropFromRow(row as Map<String, dynamic>, sensors))
        .toList(growable: false);
  }

  Future<CropModel> createCrop(CropModel crop) async {
    final row = await _client
        .from(DatabaseTables.crops)
        .insert({
          ..._cropPayload(crop),
          'assigned_manager': _client.auth.currentUser?.id,
        })
        .select(
          'id, crop_name, assigned_manager, planting_date, estimated_harvest, '
          'growth_stage, maintenance_notes, image_path, crop_status, created_at, '
          'updated_at, profiles(full_name)',
        )
        .single();

    await _recordActivity(
      activity: 'Crop record created',
      description: '${crop.name} crop record created.',
    );

    return _cropFromRow(row, await _latestSensorSnapshot());
  }

  Future<CropModel> updateCrop(CropModel crop) async {
    final row = await _client
        .from(DatabaseTables.crops)
        .update(_cropPayload(crop))
        .eq('id', crop.id)
        .select(
          'id, crop_name, assigned_manager, planting_date, estimated_harvest, '
          'growth_stage, maintenance_notes, image_path, crop_status, created_at, '
          'updated_at, profiles(full_name)',
        )
        .single();

    await _recordActivity(
      activity: 'Crop record updated',
      description: '${crop.name} crop record updated.',
    );

    return _cropFromRow(row, await _latestSensorSnapshot());
  }

  Future<void> deleteCrop(String cropId) async {
    await _client.from(DatabaseTables.crops).delete().eq('id', cropId);
    await _recordActivity(
      activity: 'Crop record deleted',
      description: 'Crop record deleted.',
    );
  }

  Future<CropModel> harvestCropToInventory({
    required CropModel crop,
    required String inventoryId,
    required String inventoryName,
    required String unit,
    required double quantity,
    required DateTime harvestDate,
    required String notes,
  }) async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null) {
      throw StateError('Sign in before recording harvest.');
    }

    final remarks = notes.trim().isEmpty ? 'Harvest recorded.' : notes.trim();

    final response = await _client.rpc<Object?>(
      'harvest_crop_to_inventory',
      params: {
        'p_crop_id': crop.id,
        'p_inventory_id': inventoryId,
        'p_quantity': quantity,
        'p_harvest_date': _dateOnly(harvestDate),
        'p_remarks': remarks,
      },
    );

    if (response is! Map<String, dynamic>) {
      throw StateError('Crop harvest database response was unreadable.');
    }

    final updatedCrop = _cropFromRow(response, await _latestSensorSnapshot());

    return updatedCrop.copyWith(
      maintenanceHistory: [
        CropMaintenanceRecord(
          activity: CropMaintenanceActivity.harvested,
          performedAt: harvestDate,
          notes:
              'Harvested $quantity $unit into $inventoryName inventory. $remarks',
          performedBy: 'Current User',
        ),
        ...crop.maintenanceHistory,
      ],
      harvestDate: harvestDate,
      imagePath: crop.imagePath,
      imageUrl: crop.imageUrl,
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
  }) async {
    final nextCrop = crop.copyWith(
      status: status,
      growthStage: growthStage,
      progress: progress,
      harvestDate: harvestDate,
      lastWateredAt: lastWateredAt,
      maintenanceHistory: [
        CropMaintenanceRecord(
          activity: activity,
          performedAt: date,
          notes: notes,
          performedBy: 'Current User',
        ),
        ...crop.maintenanceHistory,
      ],
    );

    final updatedCrop = await updateCrop(nextCrop);
    await _recordActivity(
      activity: 'Crop activity recorded',
      description: '${crop.name}: $notes',
    );

    return updatedCrop.copyWith(
      maintenanceHistory: nextCrop.maintenanceHistory,
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
    CropSensorSnapshot sensors,
  ) {
    final cropName = row['crop_name'] as String? ?? 'Crop';
    final plantingDate = _parseDate(row['planting_date']) ?? DateTime.now();
    final estimatedHarvest =
        _parseDate(row['estimated_harvest']) ??
            plantingDate.add(const Duration(days: 75));
    final status = _statusFromDb(row['crop_status'] as String?);
    final growthStage = _growthStageFromDb(row['growth_stage'] as String?);
    final notes = row['maintenance_notes'] as String?;
    final imagePath = row['image_path'] as String?;
    final manager = row['profiles'] as Map<String, dynamic>?;
    final updatedAt = _parseDateTime(row['updated_at']) ?? DateTime.now();

    return CropModel(
      id: row['id'] as String,
      name: cropName,
      variety: _varietyFor(cropName),
      location: 'SeedRover field record',
      plantingDate: plantingDate,
      estimatedHarvest: estimatedHarvest,
      growthStage: growthStage,
      status: status,
      maintenanceNotes: _maintenanceNotesFrom(notes),
      managerName: manager?['full_name'] as String? ?? 'Unassigned',
      progress: _progressFor(growthStage, status),
      sensorSnapshot: sensors,
      maintenanceHistory: [
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
      lastWateredAt: null,
    );
  }

  String? _publicCropImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return null;
    }

    return _client.storage.from(_cropImagesBucket).getPublicUrl(imagePath);
  }

  Future<CropSensorSnapshot> _latestSensorSnapshot() async {
    final rows = await _client
        .from(DatabaseTables.sensorReadings)
        .select(
          'soil_moisture, soil_temperature, environmental_temperature, humidity',
        )
        .order('recorded_at', ascending: false)
        .limit(1) as List<dynamic>;

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
      soilMoisture: _toDouble(row['soil_moisture']),
      soilTemperature: _toDouble(row['soil_temperature']),
      environmentTemperature: _toDouble(row['environmental_temperature']),
      humidity: _toDouble(row['humidity']),
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
