import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/core/utils/farmer_friendly_copy.dart';
import 'package:seedrover/features/crops/data/models/crop_model.dart';

void main() {
  test('crop stages keep canonical values and show plain-language names', () {
    expect(CropGrowthStage.pegging.label, 'Pegging');
    expect(FarmerFriendlyCopy.growthStage(CropGrowthStage.pegging.label),
        'Peanut stems reaching into the soil');
    expect(FarmerFriendlyCopy.growthStage('Juvenile'), 'Young tree growing');
    expect(FarmerFriendlyCopy.growthStage('Harvest Ready'), 'Ready to harvest');
  });

  test('older saved care task names use the same farmer-friendly wording', () {
    expect(FarmerFriendlyCopy.careTask('Monitor establishment'),
        'Check that the young plants are growing well');
    expect(FarmerFriendlyCopy.careTask('Germination and nursery review'),
        'Check for sprouts and healthy seedlings');
    expect(
        FarmerFriendlyCopy.careTask('Seeds planted'), 'Check for new sprouts');
  });

  test('sensor and status labels avoid unexplained technical terms', () {
    expect(
        FarmerFriendlyCopy.sensorLabel('Soil moisture (%)'), 'Water in soil');
    expect(FarmerFriendlyCopy.sensorLabel('Raw soil probe (ADC)'),
        'Sensor reading before setup');
    expect(CropStatus.readyForHarvest.farmerLabel, 'Ready to harvest');
  });
}
