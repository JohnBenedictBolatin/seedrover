import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/features/crops/data/models/crop_model.dart';
import 'package:seedrover/features/crops/presentation/widgets/crop_card.dart';

void main() {
  testWidgets(
      'crop card leads with planting name and ID without repeating its crop category',
      (tester) async {
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
      assignedPlantingName: 'Sunny Sitaw',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CropCard(crop: crop, selected: false, onTap: () {}),
      ),
    ));

    expect(find.text('Sunny Sitaw'), findsOneWidget);
    expect(find.text('Sitaw'), findsNothing);
    expect(find.text('CRP-2026-000083'), findsOneWidget);
  });
}
