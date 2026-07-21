enum CropGrowthStage {
  seeded,
  germinating,
  vegetative,
  flowering,
  fruiting,
  harvestReady,
  harvested;

  String get label {
    return switch (this) {
      CropGrowthStage.seeded => 'Seeded',
      CropGrowthStage.germinating => 'Germinating',
      CropGrowthStage.vegetative => 'Vegetative',
      CropGrowthStage.flowering => 'Flowering',
      CropGrowthStage.fruiting => 'Fruiting',
      CropGrowthStage.harvestReady => 'Harvest Ready',
      CropGrowthStage.harvested => 'Harvested',
    };
  }
}

enum CropStatus {
  healthy,
  needsWater,
  needsFertilizer,
  readyForHarvest,
  harvested;

  String get label {
    return switch (this) {
      CropStatus.healthy => 'Healthy',
      CropStatus.needsWater => 'Needs Water',
      CropStatus.needsFertilizer => 'Needs Fertilizer',
      CropStatus.readyForHarvest => 'Ready for Harvest',
      CropStatus.harvested => 'Harvested',
    };
  }
}

enum CropMaintenanceActivity {
  planted,
  watered,
  fertilized,
  inspected,
  harvested;

  String get label {
    return switch (this) {
      CropMaintenanceActivity.planted => 'Planted',
      CropMaintenanceActivity.watered => 'Watered',
      CropMaintenanceActivity.fertilized => 'Fertilized',
      CropMaintenanceActivity.inspected => 'Inspected',
      CropMaintenanceActivity.harvested => 'Harvested',
    };
  }
}

class CropSensorSnapshot {
  const CropSensorSnapshot({
    required this.soilMoisture,
    required this.soilTemperature,
    required this.environmentTemperature,
    required this.humidity,
  });

  final double soilMoisture;
  final double soilTemperature;
  final double environmentTemperature;
  final double humidity;
}

class CropMaintenanceRecord {
  const CropMaintenanceRecord({
    required this.activity,
    required this.performedAt,
    required this.notes,
    required this.performedBy,
  });

  final CropMaintenanceActivity activity;
  final DateTime performedAt;
  final String notes;
  final String performedBy;
}

class CropModel {
  const CropModel({
    required this.id,
    required this.name,
    required this.variety,
    required this.location,
    required this.plantingDate,
    required this.estimatedHarvest,
    required this.growthStage,
    required this.status,
    required this.maintenanceNotes,
    required this.managerName,
    required this.progress,
    required this.sensorSnapshot,
    required this.maintenanceHistory,
    required this.reminders,
    required this.notes,
    this.imagePath,
    this.imageUrl,
    this.seedCount,
    this.harvestDate,
    this.lastWateredAt,
  });

  final String id;
  final String name;
  final String variety;
  final String location;
  final DateTime plantingDate;
  final DateTime estimatedHarvest;
  final CropGrowthStage growthStage;
  final CropStatus status;
  final List<String> maintenanceNotes;
  final String managerName;
  final double progress;
  final CropSensorSnapshot sensorSnapshot;
  final List<CropMaintenanceRecord> maintenanceHistory;
  final List<String> reminders;
  final String notes;
  final String? imagePath;
  final String? imageUrl;
  final int? seedCount;
  final DateTime? harvestDate;
  final DateTime? lastWateredAt;

  int get safeSeedCount => seedCount ?? 0;

  int get cropAgeDays {
    return DateTime.now().difference(plantingDate).inDays;
  }

  int get remainingHarvestDays {
    final remaining = estimatedHarvest.difference(DateTime.now()).inDays;

    return remaining < 0 ? 0 : remaining;
  }

  bool get isHarvested => status == CropStatus.harvested;
  bool get isHarvestReady => status == CropStatus.readyForHarvest;

  CropModel copyWith({
    String? id,
    String? name,
    String? variety,
    String? location,
    DateTime? plantingDate,
    DateTime? estimatedHarvest,
    CropGrowthStage? growthStage,
    CropStatus? status,
    List<String>? maintenanceNotes,
    String? managerName,
    double? progress,
    CropSensorSnapshot? sensorSnapshot,
    List<CropMaintenanceRecord>? maintenanceHistory,
    List<String>? reminders,
    String? notes,
    Object? imagePath = _noChange,
    Object? imageUrl = _noChange,
    Object? seedCount = _noChange,
    Object? harvestDate = _noChange,
    Object? lastWateredAt = _noChange,
  }) {
    return CropModel(
      id: id ?? this.id,
      name: name ?? this.name,
      variety: variety ?? this.variety,
      location: location ?? this.location,
      plantingDate: plantingDate ?? this.plantingDate,
      estimatedHarvest: estimatedHarvest ?? this.estimatedHarvest,
      growthStage: growthStage ?? this.growthStage,
      status: status ?? this.status,
      maintenanceNotes: maintenanceNotes ?? this.maintenanceNotes,
      managerName: managerName ?? this.managerName,
      progress: progress ?? this.progress,
      sensorSnapshot: sensorSnapshot ?? this.sensorSnapshot,
      maintenanceHistory: maintenanceHistory ?? this.maintenanceHistory,
      reminders: reminders ?? this.reminders,
      notes: notes ?? this.notes,
      imagePath:
          imagePath == _noChange ? this.imagePath : imagePath as String?,
      imageUrl: imageUrl == _noChange ? this.imageUrl : imageUrl as String?,
      seedCount: seedCount == _noChange ? this.seedCount : seedCount as int?,
      harvestDate:
          harvestDate == _noChange ? this.harvestDate : harvestDate as DateTime?,
      lastWateredAt: lastWateredAt == _noChange
          ? this.lastWateredAt
          : lastWateredAt as DateTime?,
    );
  }
}

const _noChange = Object();
