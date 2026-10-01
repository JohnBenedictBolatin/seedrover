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
  });

  factory PlantingRowConfig.defaults(PlantingSeedType seed) {
    return PlantingRowConfig(
      sessionId: _uuidV4(),
      seed: seed,
      fieldLabel: '',
      targetDrops: 5,
      spacingCm: switch (seed) {
        PlantingSeedType.sitaw => 70,
        PlantingSeedType.peanut => 60,
        PlantingSeedType.calamansi => 60,
      },
      rowSpacingCm: switch (seed) {
        PlantingSeedType.sitaw => 100,
        PlantingSeedType.peanut => 40,
        PlantingSeedType.calamansi => 20,
      },
      gateOpenMs: 300,
      rakeOffsetCm: 0,
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

  PlantingRowConfig nextRow() => PlantingRowConfig(
        sessionId: _uuidV4(),
        seed: seed,
        fieldLabel: fieldLabel,
        targetDrops: targetDrops,
        spacingCm: spacingCm,
        rowSpacingCm: rowSpacingCm,
        gateOpenMs: gateOpenMs,
        rakeOffsetCm: rakeOffsetCm,
      );
}

class RoverCalibrationModel {
  const RoverCalibrationModel({
    required this.secondsPerMeter,
    required this.soilDryRaw,
    required this.soilWetRaw,
    required this.rakeToGateCm,
  });

  factory RoverCalibrationModel.fromJson(Map<String, dynamic> json) {
    return RoverCalibrationModel(
      secondsPerMeter: (json['seconds_per_meter'] as num?)?.toDouble() ?? 0,
      soilDryRaw: (json['soil_dry_raw'] as num?)?.toInt() ?? 0,
      soilWetRaw: (json['soil_wet_raw'] as num?)?.toInt() ?? 0,
      rakeToGateCm: (json['rake_to_gate_cm'] as num?)?.toDouble() ?? 0,
    );
  }

  final double secondsPerMeter;
  final int soilDryRaw;
  final int soilWetRaw;
  final double rakeToGateCm;

  bool get timedMovementReady => secondsPerMeter > 0;

  Map<String, Object?> toJson() => {
        'seconds_per_meter': secondsPerMeter,
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
    required this.soilTemperatureC,
    required this.airTemperatureC,
    required this.humidityPercent,
    required this.frontDistanceCm,
    required this.rearDistanceCm,
    this.frontObstacle = false,
    this.rearObstacle = false,
    this.frontSensorAvailable = false,
    this.rearSensorAvailable = false,
    this.obstacleSampleAgeMs,
    this.soilCapturedAtMs,
    this.soilSampleAgeMs,
    this.environmentSampleAgeMs,
    this.soilMoistureCalibrated,
    this.calibrationVersion,
    this.awaitingPhoneAck = false,
    this.rakeCommandedDown,
    required this.firmwareVersion,
    required this.distanceIsEstimated,
    required this.movementTracking,
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
      distanceCm: (json['distance_cm'] as num?)?.toDouble() ??
          (json['estimated_distance_cm'] as num?)?.toDouble() ??
          (json['encoder_distance_cm'] as num?)?.toDouble() ??
          0,
      soilRaw: json['soil_sample_available'] == true
          ? _boundedSensorNumber(json['soil_raw'], 1, 4094)?.toInt()
          : null,
      soilPercent: json['soil_moisture_calibrated'] == true &&
              _nullableText(json['calibration_version']) != null
          ? _boundedSensorNumber(json['soil_moisture_percent'], 0, 100)
          : null,
      soilTemperatureC:
          _boundedSensorNumber(json['soil_temperature_c'], -55, 125),
      airTemperatureC: _boundedSensorNumber(json['air_temperature_c'], -40, 80),
      humidityPercent: _boundedSensorNumber(json['humidity_percent'], 0, 100),
      frontDistanceCm: json['front_sensor_available'] == true
          ? _boundedSensorNumber(json['front_distance_cm'], 0, 310)
          : null,
      rearDistanceCm: json['rear_sensor_available'] == true
          ? _boundedSensorNumber(json['rear_distance_cm'], 0, 310)
          : null,
      frontObstacle: json['front_obstacle'] as bool? ?? false,
      rearObstacle: json['rear_obstacle'] as bool? ?? false,
      frontSensorAvailable: json['front_sensor_available'] as bool? ?? false,
      rearSensorAvailable: json['rear_sensor_available'] as bool? ?? false,
      obstacleSampleAgeMs: (json['obstacle_sample_age_ms'] as num?)?.toInt(),
      soilCapturedAtMs: (json['soil_capture_offset_ms'] as num?)?.toInt(),
      soilSampleAgeMs: (json['soil_sample_age_ms'] as num?)?.toInt(),
      environmentSampleAgeMs:
          (json['environment_sample_age_ms'] as num?)?.toInt(),
      soilMoistureCalibrated: !json.containsKey('soil_moisture_calibrated')
          ? null
          : json['soil_moisture_calibrated'] == true &&
                  _nullableText(json['calibration_version']) != null
              ? true
              : false,
      calibrationVersion: _nullableText(json['calibration_version']),
      awaitingPhoneAck: json['awaiting_phone_ack'] as bool? ?? false,
      rakeCommandedDown: json['rake_commanded_down'] as bool?,
      firmwareVersion: json['firmware_version']?.toString() ?? '',
      distanceIsEstimated: json['distance_is_estimated'] as bool? ?? false,
      movementTracking: json['movement_tracking']?.toString() ??
          (json.containsKey('encoder_distance_cm') ? 'encoder' : 'unknown'),
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
  final int? soilRaw;
  final double? soilPercent;
  final double? soilTemperatureC;
  final double? airTemperatureC;
  final double? humidityPercent;
  final double? frontDistanceCm;
  final double? rearDistanceCm;
  final bool frontObstacle;
  final bool rearObstacle;
  final bool frontSensorAvailable;
  final bool rearSensorAvailable;
  final int? obstacleSampleAgeMs;
  final int? soilCapturedAtMs;
  final int? soilSampleAgeMs;
  final int? environmentSampleAgeMs;
  final bool? soilMoistureCalibrated;
  final String? calibrationVersion;
  final bool awaitingPhoneAck;
  final bool? rakeCommandedDown;
  final String firmwareVersion;
  final bool distanceIsEstimated;
  final String movementTracking;
  final String? failureCode;

  bool get isTerminal => const {
        'COMPLETED',
        'CANCELLED',
        'EMERGENCY_STOPPED',
        'FAILED',
        'INTERRUPTED',
      }.contains(state);
}

class PendingPlantingReceipt {
  const PendingPlantingReceipt({
    required this.config,
    required this.status,
    required this.startedAt,
    required this.completedAt,
    this.soilCapturedAt,
    String? confirmationOutcome,
    this.remoteLogId,
    this.confirmationSynced = false,
    this.syncError,
    bool plantingConfirmed = false,
    bool? plantingSuccessful,
    this.ownerId,
  }) : confirmationOutcome = confirmationOutcome ??
            (plantingConfirmed
                ? (plantingSuccessful == false ? 'none_planted' : 'row_planted')
                : null);

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
      ),
      status: PlantingOperationStatus.fromJson(
          json['status'] as Map<String, dynamic>),
      startedAt: DateTime.parse(json['started_at'].toString()),
      completedAt: DateTime.parse(json['completed_at'].toString()),
      soilCapturedAt:
          DateTime.tryParse(json['soil_captured_at']?.toString() ?? ''),
      confirmationOutcome: _confirmationFromJson(json),
      remoteLogId: _nullableText(json['remote_log_id']),
      confirmationSynced: json['confirmation_synced'] as bool? ?? false,
      syncError: _nullableText(json['sync_error']),
      ownerId: _nullableText(json['owner_id']),
    );
  }

  final PlantingRowConfig config;
  final PlantingOperationStatus status;
  final DateTime startedAt;
  final DateTime completedAt;
  final DateTime? soilCapturedAt;
  final String? confirmationOutcome;
  final String? remoteLogId;
  final bool confirmationSynced;
  final String? syncError;
  final String? ownerId;

  bool get isConfirmed => confirmationOutcome != null;
  bool get plantingConfirmed => isConfirmed;
  bool get isHardwareConfirmedSuccess =>
      status.state == 'COMPLETED' &&
      status.completedDrops >= status.targetDrops;
  bool? get plantingSuccessful => switch (confirmationOutcome) {
        'row_planted' || 'some_planted' => true,
        'none_planted' => false,
        _ => null,
      };
  bool get readyToSynchronize => status.isTerminal;

  PendingPlantingReceipt copyWith({
    String? confirmationOutcome,
    bool clearConfirmationOutcome = false,
    String? remoteLogId,
    bool? confirmationSynced,
    String? syncError,
    bool clearSyncError = false,
    DateTime? soilCapturedAt,
    String? ownerId,
  }) {
    return PendingPlantingReceipt(
      config: config,
      status: status,
      startedAt: startedAt,
      completedAt: completedAt,
      soilCapturedAt: soilCapturedAt ?? this.soilCapturedAt,
      confirmationOutcome: clearConfirmationOutcome
          ? null
          : confirmationOutcome ?? this.confirmationOutcome,
      remoteLogId: remoteLogId ?? this.remoteLogId,
      confirmationSynced: confirmationSynced ?? this.confirmationSynced,
      syncError: clearSyncError ? null : syncError ?? this.syncError,
      ownerId: ownerId ?? this.ownerId,
    );
  }

  Map<String, Object?> toJson() => {
        ...config.toProtocolPayload(),
        'spacing_cm': config.spacingCm,
        'row_spacing_cm': config.rowSpacingCm,
        'gate_open_ms': config.gateOpenMs,
        'rake_offset_cm': config.rakeOffsetCm,
        'started_at': startedAt.toUtc().toIso8601String(),
        'completed_at': completedAt.toUtc().toIso8601String(),
        'soil_captured_at': soilCapturedAt?.toUtc().toIso8601String(),
        'confirmation_outcome': confirmationOutcome,
        'remote_log_id': remoteLogId,
        'confirmation_synced': confirmationSynced,
        'sync_error': syncError,
        'owner_id': ownerId,
        'status': {
          'state': status.state,
          'session_id': status.sessionId,
          'crop_profile': status.cropProfile,
          'field_label': status.fieldLabel,
          'target_drops': status.targetDrops,
          'completed_drops': status.completedDrops,
          'distance_cm': status.distanceCm,
          'estimated_distance_cm':
              status.distanceIsEstimated ? status.distanceCm : null,
          'distance_is_estimated': status.distanceIsEstimated,
          'movement_tracking': status.movementTracking,
          'soil_raw': status.soilRaw,
          'soil_moisture_percent': status.soilPercent,
          'soil_temperature_c': status.soilTemperatureC,
          'air_temperature_c': status.airTemperatureC,
          'humidity_percent': status.humidityPercent,
          'front_distance_cm': status.frontDistanceCm,
          'rear_distance_cm': status.rearDistanceCm,
          'front_obstacle': status.frontObstacle,
          'rear_obstacle': status.rearObstacle,
          'front_sensor_available': status.frontSensorAvailable,
          'rear_sensor_available': status.rearSensorAvailable,
          'obstacle_sample_age_ms': status.obstacleSampleAgeMs,
          'soil_capture_offset_ms': status.soilCapturedAtMs,
          'soil_moisture_calibrated': status.soilMoistureCalibrated,
          'calibration_version': status.calibrationVersion,
          'awaiting_phone_ack': status.awaitingPhoneAck,
          'firmware_version': status.firmwareVersion,
          'failure_code': status.failureCode,
        },
      };
}

String? _confirmationFromJson(Map<String, dynamic> json) {
  final explicit = _nullableText(json['confirmation_outcome']);
  if (explicit != null) return explicit;
  if (json['planting_confirmed'] == true) {
    return json['planting_successful'] == true ? 'row_planted' : 'none_planted';
  }
  return null;
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

double? _boundedSensorNumber(Object? value, double minimum, double maximum) {
  final number = (value as num?)?.toDouble();
  return number != null &&
          number.isFinite &&
          number >= minimum &&
          number <= maximum
      ? number
      : null;
}
