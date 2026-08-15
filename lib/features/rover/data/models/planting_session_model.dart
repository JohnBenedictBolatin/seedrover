import 'dart:math';

import 'rover_command_model.dart';

class PlantingRowConfig {
  const PlantingRowConfig({
    required this.sessionId,
    required this.seed,
    required this.fieldLabel,
    required this.targetDrops,
    required this.spacingCm,
    required this.rowSpacingCm,
    required this.gateOpenMs,
    required this.rakeOffsetCm,
    required this.estimatedSeedsPerDropMin,
    required this.estimatedSeedsPerDropMax,
  });

  factory PlantingRowConfig.defaults(PlantingSeedType seed) {
    return PlantingRowConfig(
      sessionId: _uuidV4(),
      seed: seed,
      fieldLabel: '',
      targetDrops: 20,
      spacingCm: switch (seed) {
        PlantingSeedType.sitaw => 50,
        PlantingSeedType.peanut => 10,
        PlantingSeedType.calamansi => 10,
      },
      rowSpacingCm: switch (seed) {
        PlantingSeedType.sitaw => 100,
        PlantingSeedType.peanut => 40,
        PlantingSeedType.calamansi => 20,
      },
      gateOpenMs: 450,
      rakeOffsetCm: 0,
      estimatedSeedsPerDropMin: 1,
      estimatedSeedsPerDropMax: seed == PlantingSeedType.peanut ? 2 : 3,
    );
  }

  final String sessionId;
  final PlantingSeedType seed;
  final String fieldLabel;
  final int targetDrops;
  final double spacingCm;
  final double rowSpacingCm;
  final int gateOpenMs;
  final double rakeOffsetCm;
  final int estimatedSeedsPerDropMin;
  final int estimatedSeedsPerDropMax;

  Map<String, Object?> toProtocolPayload() => {
        'session_id': sessionId,
        'crop_profile': seed.payloadValue,
        'field_label': fieldLabel.trim(),
        'target_drops': targetDrops,
        'spacing_cm': spacingCm,
        'row_spacing_cm': rowSpacingCm,
        'gate_open_ms': gateOpenMs,
        'rake_offset_cm': rakeOffsetCm,
      };
}

class RoverCalibrationModel {
  const RoverCalibrationModel({
    required this.leftTicksPerMeter,
    required this.rightTicksPerMeter,
    required this.soilDryRaw,
    required this.soilWetRaw,
    required this.rakeToGateCm,
  });

  factory RoverCalibrationModel.fromJson(Map<String, dynamic> json) {
    return RoverCalibrationModel(
      leftTicksPerMeter:
          (json['left_ticks_per_meter'] as num?)?.toDouble() ?? 0,
      rightTicksPerMeter:
          (json['right_ticks_per_meter'] as num?)?.toDouble() ?? 0,
      soilDryRaw: (json['soil_dry_raw'] as num?)?.toInt() ?? 0,
      soilWetRaw: (json['soil_wet_raw'] as num?)?.toInt() ?? 0,
      rakeToGateCm: (json['rake_to_gate_cm'] as num?)?.toDouble() ?? 0,
    );
  }

  final double leftTicksPerMeter;
  final double rightTicksPerMeter;
  final int soilDryRaw;
  final int soilWetRaw;
  final double rakeToGateCm;

  bool get encoderReady => leftTicksPerMeter > 0 && rightTicksPerMeter > 0;

  Map<String, Object?> toJson() => {
        'left_ticks_per_meter': leftTicksPerMeter,
        'right_ticks_per_meter': rightTicksPerMeter,
        'soil_dry_raw': soilDryRaw,
        'soil_wet_raw': soilWetRaw,
        'rake_to_gate_cm': rakeToGateCm,
      };
}

class PlantingOperationStatus {
  const PlantingOperationStatus({
    required this.state,
    required this.sessionId,
    required this.cropProfile,
    required this.fieldLabel,
    required this.targetDrops,
    required this.completedDrops,
    required this.distanceCm,
    required this.soilRaw,
    required this.soilPercent,
    required this.temperatureC,
    required this.seedLoadRaw,
    required this.firmwareVersion,
    this.failureCode,
  });

  factory PlantingOperationStatus.fromJson(Map<String, dynamic> json) {
    return PlantingOperationStatus(
      state: json['state']?.toString() ?? 'IDLE',
      sessionId: json['session_id']?.toString() ?? '',
      cropProfile: json['crop_profile']?.toString() ?? '',
      fieldLabel: json['field_label']?.toString() ?? '',
      targetDrops: (json['target_drops'] as num?)?.toInt() ?? 0,
      completedDrops: (json['completed_drops'] as num?)?.toInt() ?? 0,
      distanceCm: (json['encoder_distance_cm'] as num?)?.toDouble() ?? 0,
      soilRaw: (json['soil_raw'] as num?)?.toInt() ?? 0,
      soilPercent: (json['soil_moisture_percent'] as num?)?.toDouble() ?? 0,
      temperatureC: (json['temperature_c'] as num?)?.toDouble() ?? 0,
      seedLoadRaw: (json['seed_load_raw'] as num?)?.toInt() ?? 0,
      firmwareVersion: json['firmware_version']?.toString() ?? '',
      failureCode: _nullableText(json['failure_code']),
    );
  }

  final String state;
  final String sessionId;
  final String cropProfile;
  final String fieldLabel;
  final int targetDrops;
  final int completedDrops;
  final double distanceCm;
  final int soilRaw;
  final double soilPercent;
  final double temperatureC;
  final int seedLoadRaw;
  final String firmwareVersion;
  final String? failureCode;

  bool get isTerminal => const {
        'COMPLETED',
        'CANCELLED',
        'EMERGENCY_STOPPED',
        'FAILED',
      }.contains(state);

  int estimatedSeedMin(int seedsPerDrop) => completedDrops * seedsPerDrop;
  int estimatedSeedMax(int seedsPerDrop) => completedDrops * seedsPerDrop;
}

class PendingPlantingReceipt {
  const PendingPlantingReceipt({
    required this.config,
    required this.status,
    required this.startedAt,
    required this.completedAt,
  });

  factory PendingPlantingReceipt.fromJson(Map<String, dynamic> json) {
    final seed = PlantingSeedType.values.firstWhere(
      (value) => value.payloadValue == json['crop_profile'],
      orElse: () => PlantingSeedType.sitaw,
    );
    return PendingPlantingReceipt(
      config: PlantingRowConfig(
        sessionId: json['session_id'].toString(),
        seed: seed,
        fieldLabel: json['field_label']?.toString() ?? '',
        targetDrops: (json['target_drops'] as num).toInt(),
        spacingCm: (json['spacing_cm'] as num).toDouble(),
        rowSpacingCm: (json['row_spacing_cm'] as num).toDouble(),
        gateOpenMs: (json['gate_open_ms'] as num).toInt(),
        rakeOffsetCm: (json['rake_offset_cm'] as num).toDouble(),
        estimatedSeedsPerDropMin:
            (json['estimated_seeds_min'] as num?)?.toInt() ?? 1,
        estimatedSeedsPerDropMax:
            (json['estimated_seeds_max'] as num?)?.toInt() ?? 3,
      ),
      status: PlantingOperationStatus.fromJson(
          json['status'] as Map<String, dynamic>),
      startedAt: DateTime.parse(json['started_at'].toString()),
      completedAt: DateTime.parse(json['completed_at'].toString()),
    );
  }

  final PlantingRowConfig config;
  final PlantingOperationStatus status;
  final DateTime startedAt;
  final DateTime completedAt;

  Map<String, Object?> toJson() => {
        ...config.toProtocolPayload(),
        'spacing_cm': config.spacingCm,
        'row_spacing_cm': config.rowSpacingCm,
        'gate_open_ms': config.gateOpenMs,
        'rake_offset_cm': config.rakeOffsetCm,
        'estimated_seeds_min': config.estimatedSeedsPerDropMin,
        'estimated_seeds_max': config.estimatedSeedsPerDropMax,
        'started_at': startedAt.toUtc().toIso8601String(),
        'completed_at': completedAt.toUtc().toIso8601String(),
        'status': {
          'state': status.state,
          'session_id': status.sessionId,
          'crop_profile': status.cropProfile,
          'field_label': status.fieldLabel,
          'target_drops': status.targetDrops,
          'completed_drops': status.completedDrops,
          'encoder_distance_cm': status.distanceCm,
          'soil_raw': status.soilRaw,
          'soil_moisture_percent': status.soilPercent,
          'temperature_c': status.temperatureC,
          'seed_load_raw': status.seedLoadRaw,
          'firmware_version': status.firmwareVersion,
          'failure_code': status.failureCode,
        },
      };
}

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String? _nullableText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
