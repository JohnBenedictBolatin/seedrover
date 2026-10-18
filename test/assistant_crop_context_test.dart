import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/features/assistant/data/repositories/assistant_context_repository.dart';
import 'package:seedrover/features/crops/data/models/crop_model.dart';

void main() {
  test('assistant identifies a planting by its friendly name and crop type',
      () {
    final crop = CropModel(
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
      fieldLabel: 'North field',
      assignedPlantingName: 'Sunny Sitaw',
    );

    final context = cropContextForAssistant(crop);

    expect(context['name'], 'Sunny Sitaw');
    expect(context['cropType'], 'Sitaw');
    expect(context['field'], 'North field');
  });
}
