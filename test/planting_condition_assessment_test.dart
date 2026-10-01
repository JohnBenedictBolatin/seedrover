import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/features/rover/data/models/planting_condition_assessment.dart';
import 'package:seedrover/features/rover/data/models/planting_session_model.dart';
import 'package:seedrover/features/rover/data/models/planting_soil_precheck.dart';
import 'package:seedrover/features/rover/data/models/rover_command_model.dart';

void main() {
  final now = DateTime.now();
  const calibration = RoverCalibrationModel(
    secondsPerMeter: 1,
    soilDryRaw: 2100,
    soilWetRaw: 1050,
    rakeToGateCm: 10,
  );

  PlantingSoilPrecheck sample({
    int raw = 2100,
    double soilTemperature = 24,
    Object? airTemperature = 25,
    Object? humidity = 60,
    DateTime? recordedAt,
  }) =>
      PlantingSoilPrecheck.fromJson(
        {
          'soil_moisture_percent': 3.6,
          'soil_temperature_c': soilTemperature,
          'air_temperature_c': airTemperature,
          'humidity_percent': humidity,
          'soil_moisture_calibrated': true,
          'calibration_version': 'soil-linear-v1',
          'soil_sample_available': true,
          'soil_raw': raw,
          'sampled_at_ms': 1000,
          'recorded_at': (recordedAt ?? now).toIso8601String(),
        },
        calibration: calibration,
      );

  PlantingConditionAssessment evaluate(
    PlantingSoilPrecheck readings, {
    PlantingSeedType seed = PlantingSeedType.peanut,
    DateTime? at,
  }) =>
      PlantingConditionAssessment.evaluate(
        seed: seed,
        readings: readings,
        assessedAt: at ?? now,
      );

  test('peanut score counts only moisture and supported soil temperature', () {
    final result = evaluate(sample());
    expect(result.score, 100);
    expect(result.matchedChecks, 2);
    expect(result.summary, 'Current soil checks match');

    expect(evaluate(sample(soilTemperature: 19.9)).score, 50);
    expect(evaluate(sample(soilTemperature: 18)).score, 50);
    expect(evaluate(sample(soilTemperature: 20)).score, 100);
    expect(evaluate(sample(soilTemperature: 30)).score, 100);
    expect(evaluate(sample(soilTemperature: 30.1)).score, 50);
    expect(evaluate(sample(soilTemperature: 17.9)).soilTemperatureAdvice,
        contains('stronger cold-soil concern'));
  });

  test('moisture warnings remain visible even when temperature matches', () {
    final result = evaluate(sample(raw: 1050));
    expect(result.score, 50);
    expect(result.hasMoistureConcern, isTrue);
    expect(result.moistureAdvice, 'Too wet');
    expect(result.summary, 'Conditions need attention');
    expect(evaluate(sample(raw: 2211)).moistureAdvice, 'Too dry');
    expect(evaluate(sample(raw: 1900)).moistureAdvice, 'Too wet');
    expect(evaluate(sample(raw: 1155)).moistureAdvice, 'Too wet');
  });

  test('missing environment hides score but retains available advice', () {
    final missingAir = evaluate(sample(airTemperature: null));
    final missingHumidity = evaluate(sample(humidity: null));
    expect(missingAir.score, isNull);
    expect(missingAir.summary, 'Assessment incomplete');
    expect(missingHumidity.score, isNull);
    expect(missingHumidity.moistureAdvice, 'Good for planting');
    expect(evaluate(sample(airTemperature: 55)).score, isNull);
    expect(evaluate(sample(humidity: 100)).score, isNull);
  });

  test('sitaw and calamansi do not receive unsupported scores', () {
    final sitaw = evaluate(sample(), seed: PlantingSeedType.sitaw);
    final calamansi = evaluate(sample(), seed: PlantingSeedType.calamansi);
    expect(sitaw.score, isNull);
    expect(
        sitaw.soilTemperatureAdvice, contains('full sitaw temperature range'));
    expect(
      evaluate(sample(soilTemperature: 22), seed: PlantingSeedType.sitaw)
          .soilTemperatureAdvice,
      contains('has not exceeded'),
    );
    expect(
      evaluate(sample(soilTemperature: 22.1), seed: PlantingSeedType.sitaw)
          .soilTemperatureAdvice,
      contains('exceeds the published'),
    );
    expect(calamansi.score, isNull);
    expect(calamansi.soilTemperatureAdvice, contains('not established'));
  });

  test('expired pre-check loses score and prompts a fresh assessment', () {
    final expired = evaluate(
      sample(recordedAt: now.subtract(const Duration(seconds: 61))),
    );
    expect(expired.score, isNull);
    expect(expired.summary, 'Assessment incomplete');
    expect(expired.limitations.join(' '), contains('older than 60 seconds'));
  });

  test('FAO VPD formula responds to temperature and humidity', () {
    final reference = PlantingConditionAssessment.calculateVpdKpa(25, 50)!;
    final humid = PlantingConditionAssessment.calculateVpdKpa(25, 80)!;
    final cool = PlantingConditionAssessment.calculateVpdKpa(20, 50)!;
    expect(reference, closeTo(1.584, .01));
    expect(humid, lessThan(reference));
    expect(cool, lessThan(reference));
  });
}
