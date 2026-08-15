import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/features/rover/data/models/planting_session_model.dart';
import 'package:seedrover/features/rover/data/models/rover_command_model.dart';

void main() {
  group('planting row configuration', () {
    test('uses crop-specific spacing defaults', () {
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
        );

    expect(status('PLANTING').isTerminal, isFalse);
    expect(status('PAUSED').isTerminal, isFalse);
    expect(status('COMPLETED').isTerminal, isTrue);
    expect(status('CANCELLED').isTerminal, isTrue);
    expect(status('EMERGENCY_STOPPED').isTerminal, isTrue);
    expect(status('FAILED').isTerminal, isTrue);
  });
}
