import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/features/crops/data/models/crop_model.dart';

CropModel _crop({String? assigned, String? custom}) => CropModel(
      id: 'crop-1',
      batchCode: 'CRP-2026-000083',
      name: 'Sitaw',
      variety: 'Not recorded',
      location: 'North field',
      plantingDate: DateTime(2026, 1, 1),
      estimatedHarvest: null,
      growthStage: CropGrowthStage.vegetative,
      status: CropStatus.active,
      maintenanceNotes: const [],
      managerName: 'Farmer',
      sensorSnapshot: const CropSensorSnapshot(
        soilMoisture: null,
        soilTemperature: null,
        environmentTemperature: null,
        humidity: null,
      ),
      maintenanceHistory: const [],
      reminders: const [],
      notes: '',
      assignedPlantingName: assigned,
      customPlantingName: custom,
    );

void main() {
  test('keeps crop type separate and uses the assigned planting name', () {
    final crop = _crop(assigned: 'Sunny Sitaw');

    expect(crop.displayName, 'Sunny Sitaw');
    expect(crop.name, 'Sitaw');
    expect(crop.trackingCode, 'CRP-2026-000083');
  });

  test('custom name overrides assigned name and can be reset', () {
    final named = _crop(assigned: 'Sunny Sitaw', custom: 'South Garden Row');

    expect(named.displayName, 'South Garden Row');
    expect(named.copyWith(customPlantingName: null).displayName, 'Sunny Sitaw');
  });

  test('legacy model fallback remains friendly without changing crop type', () {
    final crop = _crop();

    expect(crop.displayName, 'Garden Sitaw');
    expect(crop.name, 'Sitaw');
  });
}
