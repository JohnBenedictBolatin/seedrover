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

class CropWeatherSnapshot {
  const CropWeatherSnapshot({
    required this.currentCondition,
    this.nextRainAt,
    this.temperatureC,
    this.humidityPercent,
    this.rainChancePercent,
    this.fetchedAt,
  });

  final String currentCondition;
  final DateTime? nextRainAt;
  final double? temperatureC;
  final double? humidityPercent;
  final double? rainChancePercent;
  final DateTime? fetchedAt;
}

class CropSensorSnapshot {
  const CropSensorSnapshot({
    required this.soilMoisture,
    required this.soilTemperature,
    required this.environmentTemperature,
    required this.humidity,
    this.recordedAt,
  });

  final double soilMoisture;
  final double soilTemperature;
  final double environmentTemperature;
  final double humidity;
  final DateTime? recordedAt;
}

class CropMaintenanceRecord {
  const CropMaintenanceRecord({
    required this.activity,
    required this.performedAt,
    required this.notes,
    required this.performedBy,
    this.quantity,
    this.unit,
    this.material,
  });

  final CropMaintenanceActivity activity;
  final DateTime performedAt;
  final String notes;
  final String performedBy;
  final double? quantity;
  final String? unit;
  final String? material;
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
    this.plantingSource = 'Legacy',
    this.fieldLabel = 'Field not labeled',
    this.fieldAreaM2,
    this.completedDrops = 0,
    this.estimatedSeedMin,
    this.estimatedSeedMax,
    this.harvestWindowStart,
    this.harvestWindowEnd,
    this.forecastConfidence = 'Low',
    this.expectedStage = 'Review stage',
    this.careStatus = 'Review crop condition',
    this.propagationMethod = 'Unknown',
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
  final String plantingSource;
  final String fieldLabel;
  final double? fieldAreaM2;
  final int completedDrops;
  final int? estimatedSeedMin;
  final int? estimatedSeedMax;
  final DateTime? harvestWindowStart;
  final DateTime? harvestWindowEnd;
  final String forecastConfidence;
  final String expectedStage;
  final String careStatus;
  final String propagationMethod;

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
    String? plantingSource,
    String? fieldLabel,
    Object? fieldAreaM2 = _noChange,
    int? completedDrops,
    Object? estimatedSeedMin = _noChange,
    Object? estimatedSeedMax = _noChange,
    Object? harvestWindowStart = _noChange,
    Object? harvestWindowEnd = _noChange,
    String? forecastConfidence,
    String? expectedStage,
    String? careStatus,
    String? propagationMethod,
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
      imagePath: imagePath == _noChange ? this.imagePath : imagePath as String?,
      imageUrl: imageUrl == _noChange ? this.imageUrl : imageUrl as String?,
      seedCount: seedCount == _noChange ? this.seedCount : seedCount as int?,
      harvestDate: harvestDate == _noChange
          ? this.harvestDate
          : harvestDate as DateTime?,
      lastWateredAt: lastWateredAt == _noChange
          ? this.lastWateredAt
          : lastWateredAt as DateTime?,
      plantingSource: plantingSource ?? this.plantingSource,
      fieldLabel: fieldLabel ?? this.fieldLabel,
      fieldAreaM2:
          fieldAreaM2 == _noChange ? this.fieldAreaM2 : fieldAreaM2 as double?,
      completedDrops: completedDrops ?? this.completedDrops,
      estimatedSeedMin: estimatedSeedMin == _noChange
          ? this.estimatedSeedMin
          : estimatedSeedMin as int?,
      estimatedSeedMax: estimatedSeedMax == _noChange
          ? this.estimatedSeedMax
          : estimatedSeedMax as int?,
      harvestWindowStart: harvestWindowStart == _noChange
          ? this.harvestWindowStart
          : harvestWindowStart as DateTime?,
      harvestWindowEnd: harvestWindowEnd == _noChange
          ? this.harvestWindowEnd
          : harvestWindowEnd as DateTime?,
      forecastConfidence: forecastConfidence ?? this.forecastConfidence,
      expectedStage: expectedStage ?? this.expectedStage,
      careStatus: careStatus ?? this.careStatus,
      propagationMethod: propagationMethod ?? this.propagationMethod,
    );
  }
}

const _noChange = Object();
