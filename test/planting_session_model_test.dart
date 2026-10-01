import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/features/rover/data/models/planting_session_model.dart';
import 'package:seedrover/features/rover/data/models/rover_command_model.dart';

void main() {
  group('planting row configuration', () {
    test('uses crop-specific spacing defaults', () {
      expect(PlantingRowConfig.defaults(PlantingSeedType.sitaw).targetDrops, 5);
      expect(PlantingRowConfig.defaults(PlantingSeedType.sitaw).spacingCm, 70);
      expect(PlantingRowConfig.defaults(PlantingSeedType.peanut).spacingCm, 60);
      expect(
          PlantingRowConfig.defaults(PlantingSeedType.calamansi).spacingCm, 60);
      expect(
          PlantingRowConfig.defaults(PlantingSeedType.sitaw).gateOpenMs, 300);
      expect(
          PlantingRowConfig.defaults(PlantingSeedType.sitaw).rowSpacingCm, 100);
      expect(
          PlantingRowConfig.defaults(PlantingSeedType.peanut).rowSpacingCm, 40);
    });

    test('generates a valid client UUID for idempotent replay', () {
      final id =
          PlantingRowConfig.defaults(PlantingSeedType.calamansi).sessionId;
      expect(
          id,
          matches(RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    });

    test('keeps the selected field in the next row and protocol payload', () {
      final config = PlantingRowConfig.defaults(PlantingSeedType.sitaw);
      final selected = PlantingRowConfig(
        sessionId: config.sessionId,
        seed: config.seed,
        fieldLabel: 'Field 3',
        targetDrops: config.targetDrops,
        spacingCm: config.spacingCm,
        rowSpacingCm: config.rowSpacingCm,
        gateOpenMs: config.gateOpenMs,
        rakeOffsetCm: config.rakeOffsetCm,
      );

      expect(selected.nextRow().fieldLabel, 'Field 3');
      expect(selected.toProtocolPayload()['field_label'], 'Field 3');
    });

    test('uses timed calibration without encoder values', () {
      final calibration = RoverCalibrationModel.fromJson({
        'seconds_per_meter': 5.4,
        'soil_dry_raw': 3200,
        'soil_wet_raw': 1300,
        'rake_to_gate_cm': 18,
      });

      expect(calibration.timedMovementReady, isTrue);
      expect(calibration.secondsPerMeter, 5.4);
      expect(calibration.toJson(), isNot(contains('left_ticks_per_meter')));
    });
  });

  test('reads timed distance as an estimate', () {
    final status = PlantingOperationStatus.fromJson({
      'state': 'PLANTING',
      'distance_cm': 125.5,
      'distance_is_estimated': true,
      'movement_tracking': 'timed_estimate',
    });

    expect(status.distanceCm, 125.5);
    expect(status.distanceIsEstimated, isTrue);
    expect(status.movementTracking, 'timed_estimate');
  });

  test('parses local sensor sample ages from rover status', () {
    final status = PlantingOperationStatus.fromJson({
      'soil_sample_age_ms': 12000,
      'environment_sample_age_ms': 2000,
    });

    expect(status.soilSampleAgeMs, 12000);
    expect(status.environmentSampleAgeMs, 2000);
  });

  test('keeps rake position as firmware-reported command state', () {
    final commandedDown = PlantingOperationStatus.fromJson({
      'rake_commanded_down': true,
    });
    final legacyFirmware = PlantingOperationStatus.fromJson(const {});

    expect(commandedDown.rakeCommandedDown, isTrue);
    expect(legacyFirmware.rakeCommandedDown, isNull);
  });

  test('keeps a real zero and hides uncalibrated moisture percentages', () {
    final calibrated = PlantingOperationStatus.fromJson({
      'soil_moisture_percent': 0,
      'soil_moisture_calibrated': true,
      'calibration_version': 'soil-linear-v1',
      'soil_temperature_c': 0,
      'humidity_percent': 0,
      'soil_raw': 0,
      'soil_sample_available': false,
      'front_distance_cm': 0,
      'front_sensor_available': false,
    });
    final uncalibrated = PlantingOperationStatus.fromJson({
      'soil_moisture_percent': 42,
      'soil_moisture_calibrated': false,
      'calibration_version': null,
      'soil_temperature_c': null,
    });
    final calibrationUnknown = PlantingOperationStatus.fromJson({
      'soil_moisture_percent': 42,
    });

    expect(calibrated.soilPercent, 0);
    expect(calibrated.soilTemperatureC, 0);
    expect(calibrated.humidityPercent, 0);
    expect(calibrated.soilRaw, isNull);
    expect(calibrated.frontDistanceCm, isNull);
    expect(uncalibrated.soilPercent, isNull);
    expect(uncalibrated.soilMoistureCalibrated, isFalse);
    expect(calibrationUnknown.soilPercent, isNull);
    expect(calibrationUnknown.soilMoistureCalibrated, isNull);
    expect(uncalibrated.soilTemperatureC, isNull);
  });

  test('only terminal rover states produce planting receipts', () {
    PlantingOperationStatus status(String state) => PlantingOperationStatus(
          state: state,
          sessionId: '2c51284a-08b0-43c8-89e8-1b8c123081cb',
          cropProfile: 'sitaw',
          fieldLabel: 'North row',
          targetDrops: 20,
          completedDrops: 4,
          distanceCm: 150,
          soilRaw: 2000,
          soilPercent: 55,
          soilTemperatureC: 28,
          airTemperatureC: null,
          humidityPercent: null,
          frontDistanceCm: null,
          rearDistanceCm: null,
          firmwareVersion: 'test',
          distanceIsEstimated: true,
          movementTracking: 'timed_estimate',
        );

    expect(status('PLANTING').isTerminal, isFalse);
    expect(status('PAUSED').isTerminal, isFalse);
    expect(status('COMPLETED').isTerminal, isTrue);
    expect(status('CANCELLED').isTerminal, isTrue);
    expect(status('EMERGENCY_STOPPED').isTerminal, isTrue);
    expect(status('FAILED').isTerminal, isTrue);
  });

  test('completed hardware receipt synchronizes without operator confirmation',
      () {
    final config = PlantingRowConfig.defaults(PlantingSeedType.sitaw);
    final receipt = PendingPlantingReceipt(
      config: config,
      status: PlantingOperationStatus(
        state: 'COMPLETED',
        sessionId: config.sessionId,
        cropProfile: 'sitaw',
        fieldLabel: 'North row',
        targetDrops: 5,
        completedDrops: 5,
        distanceCm: 200,
        soilRaw: 2000,
        soilPercent: 55,
        soilTemperatureC: 28,
        airTemperatureC: null,
        humidityPercent: null,
        frontDistanceCm: null,
        rearDistanceCm: null,
        firmwareVersion: 'test',
        distanceIsEstimated: true,
        movementTracking: 'timed_estimate',
      ),
      startedAt: DateTime.utc(2026, 8, 18),
      completedAt: DateTime.utc(2026, 8, 18, 0, 1),
    );

    expect(receipt.plantingConfirmed, isFalse);
    expect(receipt.isHardwareConfirmedSuccess, isTrue);
    expect(receipt.readyToSynchronize, isTrue);
  });
}
