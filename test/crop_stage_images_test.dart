import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/features/crops/data/models/crop_model.dart';
import 'package:seedrover/features/crops/presentation/widgets/crop_plant_image.dart';

CropModel cropFor(CropGrowthStage stage,
    {required String name, CropStatus status = CropStatus.active}) {
  return CropModel(
    id: 'crop-stage-image-test',
    name: name,
    variety: 'Not recorded',
    location: 'Test field',
    plantingDate: DateTime(2026, 1, 1),
    estimatedHarvest: null,
    growthStage: stage,
    status: status,
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
  );
}

void main() {
  testWidgets('each crop uses artwork for its recorded growth stage',
      (tester) async {
    final crops = [
      (cropFor(CropGrowthStage.trellising, name: 'Sitaw'), 'sitaw_trellising'),
      (
        cropFor(CropGrowthStage.firstBearing, name: 'Calamansi'),
        'calamansi_first_bearing'
      ),
      (cropFor(CropGrowthStage.pegging, name: 'Peanut'), 'peanut_pegging'),
    ];

    for (final (crop, expectedAsset) in crops) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CropPlantImage(crop: crop)),
      ));

      final image = tester.widget<Image>(find.byType(Image).first);
      expect((image.image as AssetImage).assetName,
          'assets/images/crops/$expectedAsset.webp');
      await tester.pumpAndSettle();
    }
  });

  testWidgets('a care warning preserves the crop stage image', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CropPlantImage(
          crop: cropFor(
            CropGrowthStage.podDevelopment,
            name: 'Peanut',
            status: CropStatus.needsAttention,
          ),
        ),
      ),
    ));

    final image = tester.widget<Image>(find.byType(Image).first);
    expect((image.image as AssetImage).assetName,
        'assets/images/crops/peanut_pod_development.webp');
    await tester.pumpAndSettle();
  });
}
