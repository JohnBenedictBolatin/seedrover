import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/features/rover/data/models/planting_session_model.dart';
import 'package:seedrover/features/rover/data/models/rover_command_model.dart';

void main() {
  group('planting row configuration', () {
    test('uses crop-specific spacing defaults', () {
      expect(PlantingRowConfig.defaults(PlantingSeedType.sitaw).targetDrops, 5);
      expect(PlantingRowConfig.defaults(PlantingSeedType.sitaw).spacingCm, 50);
      expect(PlantingRowConfig.defaults(PlantingSeedType.peanut).spacingCm, 10);
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
          temperatureC: 28,
          seedLoadRaw: 800,
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
}
