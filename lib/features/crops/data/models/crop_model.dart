enum CropGrowthStage {
  seeded,
  seedbed,
  germinating,
  nurserySeedling,
  transplantReview,
  establishing,
  juvenile,
  vegetative,
  trellising,
  flowering,
  podFormation,
  pegging,
  podDevelopment,
  maturityCheck,
  firstBearing,
  fruiting,
  harvestReady,
  harvested,
  other;

  String get label => switch (this) {
        CropGrowthStage.seeded => 'Seeded',
        CropGrowthStage.seedbed => 'Seedbed',
        CropGrowthStage.germinating => 'Germinating',
        CropGrowthStage.nurserySeedling => 'Nursery Seedling',
        CropGrowthStage.transplantReview => 'Transplant Review',
        CropGrowthStage.establishing => 'Establishing',
        CropGrowthStage.juvenile => 'Juvenile',
        CropGrowthStage.vegetative => 'Vegetative',
        CropGrowthStage.trellising => 'Trellising',
        CropGrowthStage.flowering => 'Flowering',
        CropGrowthStage.podFormation => 'Pod Formation',
        CropGrowthStage.pegging => 'Pegging',
        CropGrowthStage.podDevelopment => 'Pod Development',
        CropGrowthStage.maturityCheck => 'Maturity Check',
        CropGrowthStage.firstBearing => 'First Bearing',
        CropGrowthStage.fruiting => 'Fruiting',
        CropGrowthStage.harvestReady => 'Harvest Ready',
        CropGrowthStage.harvested => 'Completed',
        CropGrowthStage.other => 'Review recorded stage',
      };
}

enum CropStatus {
  active,
  needsAttention,
  readyForHarvest,
  harvested,
  notHarvested;

  String get label => switch (this) {
        CropStatus.active => 'Active',
        CropStatus.needsAttention => 'Needs Attention',
        CropStatus.readyForHarvest => 'Harvest Ready',
        CropStatus.harvested => 'Harvested',
        CropStatus.notHarvested => 'Closed without harvest',
      };
}

enum CropMaintenanceActivity {
  planted,
  watered,
  fertilized,
  inspected,
  stageObserved,
  transplanted,
  harvested,
  notHarvested,
  plantingFailed;

  String get label {
    return switch (this) {
      CropMaintenanceActivity.planted => 'Planted',
      CropMaintenanceActivity.watered => 'Watered',
      CropMaintenanceActivity.fertilized => 'Fertilized',
      CropMaintenanceActivity.inspected => 'Inspected',
      CropMaintenanceActivity.stageObserved => 'Stage Observed',
      CropMaintenanceActivity.transplanted => 'Transplanted',
      CropMaintenanceActivity.harvested => 'Harvested',
      CropMaintenanceActivity.notHarvested => 'Not Harvested',
      CropMaintenanceActivity.plantingFailed => 'Planting Failed',
    };
  }
}

class CropWeatherSnapshot {
  const CropWeatherSnapshot({
    required this.currentCondition,
    this.source = 'Unavailable',
    this.unavailableMessage,
    this.nextRainAt,
    this.temperatureC,
    this.humidityPercent,
    this.rainChancePercent,
    this.fetchedAt,
  });

  final String currentCondition;
  final String source;
  final String? unavailableMessage;
  final DateTime? nextRainAt;
  final double? temperatureC;
  final double? humidityPercent;
  final double? rainChancePercent;
  final DateTime? fetchedAt;
}

class CropSensorSnapshot {
  const CropSensorSnapshot({
    required this.soilMoisture,
    this.soilRaw,
    required this.soilTemperature,
    required this.environmentTemperature,
    required this.humidity,
    this.recordedAt,
    this.source,
    this.provenanceStatus,
    this.soilMoistureCalibrated,
    this.calibrationVersion,
  });

  final double? soilMoisture;
  final int? soilRaw;
  final double? soilTemperature;
  final double? environmentTemperature;
  final double? humidity;
  final DateTime? recordedAt;
  final String? source;
  final String? provenanceStatus;
  final bool? soilMoistureCalibrated;
  final String? calibrationVersion;
}

class CropSensorReading {
  const CropSensorReading({
    required this.id,
    required this.recordedAt,
    required this.source,
    required this.provenanceStatus,
    this.soilRaw,
    this.soilMoisture,
    this.soilTemperature,
    this.environmentTemperature,
    this.humidity,
    this.soilMoistureCalibrated,
    this.calibrationVersion,
  });

  final String id;
  final DateTime recordedAt;
  final String source;
  final String provenanceStatus;
  final int? soilRaw;
  final double? soilMoisture;
  final double? soilTemperature;
  final double? environmentTemperature;
  final double? humidity;
  final bool? soilMoistureCalibrated;
  final String? calibrationVersion;

  bool get isFresh {
    final age = DateTime.now().difference(recordedAt);
    return !age.isNegative && age <= const Duration(seconds: 60);
  }
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
    this.observedStage,
    this.source = 'User',
    this.id,
    this.photoPaths = const [],
  });

  final CropMaintenanceActivity activity;
  final DateTime performedAt;
  final String notes;
  final String performedBy;
  final double? quantity;
  final String? unit;
  final String? material;
  final String? observedStage;
  final String source;
  final String? id;
  final List<String> photoPaths;
}

class CropCareTask {
  const CropCareTask({
    required this.id,
    required this.title,
    required this.recommendation,
    required this.type,
    required this.dueAt,
    required this.priority,
    required this.status,
  });

  final String id;
  final String title;
  final String recommendation;
  final String type;
  final DateTime dueAt;
  final String priority;
  final String status;
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
    required this.sensorSnapshot,
    required this.maintenanceHistory,
    required this.reminders,
    required this.notes,
    this.batchCode = '',
    this.imagePath,
    this.imageUrl,
    this.harvestDate,
    this.lastWateredAt,
    this.plantingSource = 'Legacy',
    this.fieldLabel = 'Field not labeled',
    this.fieldAreaM2,
    this.harvestWindowStart,
    this.harvestWindowEnd,
    this.forecastConfidence = 'Low',
    this.expectedStage = 'Review stage',
    this.careStatus = 'Review crop condition',
    this.propagationMethod = 'Unknown',
    this.recordedGrowthStage,
    this.assignedManagerId,
    this.cropProfileKey,
    this.harvestedQuantity,
    this.harvestInventoryName,
    this.harvestTaskCount = 0,
    this.profileStages = const [],
    this.careTasks = const [],
    this.plantingTargetDrops,
    this.plantingCompletedDrops,
  });

  final String id;
  final String batchCode;
  final String name;
  final String variety;
  final String location;
  final DateTime plantingDate;
  final DateTime? estimatedHarvest;
  final CropGrowthStage growthStage;
  final CropStatus status;
  final List<String> maintenanceNotes;
  final String managerName;
  final CropSensorSnapshot sensorSnapshot;
  final List<CropMaintenanceRecord> maintenanceHistory;
  final List<String> reminders;
  final String notes;
  final String? imagePath;
  final String? imageUrl;
  final DateTime? harvestDate;
  final DateTime? lastWateredAt;
  final String plantingSource;
  final String fieldLabel;
  final double? fieldAreaM2;
  final DateTime? harvestWindowStart;
  final DateTime? harvestWindowEnd;
  final String forecastConfidence;
  final String expectedStage;
  final String careStatus;
  final String propagationMethod;
  final String? recordedGrowthStage;
  final String? assignedManagerId;
  final String? cropProfileKey;
  final double? harvestedQuantity;
  final String? harvestInventoryName;
  final int harvestTaskCount;
  final List<String> profileStages;
  final List<CropCareTask> careTasks;
  final int? plantingTargetDrops;
  final int? plantingCompletedDrops;

  String get growthStageLabel => recordedGrowthStage?.trim().isNotEmpty == true
      ? recordedGrowthStage!
      : growthStage.label;

  int get cropAgeDays {
    return DateTime.now().difference(plantingDate).inDays;
  }

  int get remainingHarvestDays {
    final date = estimatedHarvest;
    if (date == null) return 0;
    final remaining = date.difference(DateTime.now()).inDays;

    return remaining < 0 ? 0 : remaining;
  }

  bool get isHarvested => status == CropStatus.harvested;
  bool get isCompleted =>
      status == CropStatus.harvested || status == CropStatus.notHarvested;
  bool get isHarvestReady => status == CropStatus.readyForHarvest;

  String get trackingCode {
    if (batchCode.trim().isNotEmpty) return batchCode.trim();
    final compactId = id.replaceAll('-', '');
    final suffixLength = compactId.length < 8 ? compactId.length : 8;
    final suffix = compactId.substring(0, suffixLength);
    return 'CRP-LEGACY-${suffix.toUpperCase()}';
  }

  CropModel copyWith({
    String? id,
    String? batchCode,
    String? name,
    String? variety,
    String? location,
    DateTime? plantingDate,
    DateTime? estimatedHarvest,
    CropGrowthStage? growthStage,
    CropStatus? status,
    List<String>? maintenanceNotes,
    String? managerName,
    CropSensorSnapshot? sensorSnapshot,
    List<CropMaintenanceRecord>? maintenanceHistory,
    List<String>? reminders,
    String? notes,
    Object? imagePath = _noChange,
    Object? imageUrl = _noChange,
    Object? harvestDate = _noChange,
    Object? lastWateredAt = _noChange,
    String? plantingSource,
    String? fieldLabel,
    Object? fieldAreaM2 = _noChange,
    Object? harvestWindowStart = _noChange,
    Object? harvestWindowEnd = _noChange,
    String? forecastConfidence,
    String? expectedStage,
    String? careStatus,
    String? propagationMethod,
    String? recordedGrowthStage,
    Object? plantingTargetDrops = _noChange,
    Object? plantingCompletedDrops = _noChange,
  }) {
    return CropModel(
      id: id ?? this.id,
      batchCode: batchCode ?? this.batchCode,
      name: name ?? this.name,
      variety: variety ?? this.variety,
      location: location ?? this.location,
      plantingDate: plantingDate ?? this.plantingDate,
      estimatedHarvest: estimatedHarvest ?? this.estimatedHarvest,
      growthStage: growthStage ?? this.growthStage,
      status: status ?? this.status,
      maintenanceNotes: maintenanceNotes ?? this.maintenanceNotes,
      managerName: managerName ?? this.managerName,
      sensorSnapshot: sensorSnapshot ?? this.sensorSnapshot,
      maintenanceHistory: maintenanceHistory ?? this.maintenanceHistory,
      reminders: reminders ?? this.reminders,
      notes: notes ?? this.notes,
      imagePath: imagePath == _noChange ? this.imagePath : imagePath as String?,
      imageUrl: imageUrl == _noChange ? this.imageUrl : imageUrl as String?,
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
      recordedGrowthStage: recordedGrowthStage ?? this.recordedGrowthStage,
      plantingTargetDrops: plantingTargetDrops == _noChange
          ? this.plantingTargetDrops
          : plantingTargetDrops as int?,
      plantingCompletedDrops: plantingCompletedDrops == _noChange
          ? this.plantingCompletedDrops
          : plantingCompletedDrops as int?,
    );
  }
}

const _noChange = Object();
