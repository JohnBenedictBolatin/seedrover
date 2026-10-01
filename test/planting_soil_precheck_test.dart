import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/features/rover/data/models/planting_soil_precheck.dart';
import 'package:seedrover/features/rover/data/models/planting_session_model.dart';
import 'package:seedrover/shared/models/soil_moisture_diagnosis.dart';

void main() {
  final sampledAt = DateTime.now();

  Map<String, dynamic> readings({
    Object? moisture = 42.5,
    Object? temperature = 24.0,
    bool calibrated = true,
    bool sampleAvailable = true,
    Object? raw = 1800,
    String? calibrationVersion = 'soil-linear-v1',
  }) =>
      {
        'soil_moisture_percent': moisture,
        'soil_temperature_c': temperature,
        'air_temperature_c': 25.0,
        'humidity_percent': 60.0,
        'soil_moisture_calibrated': calibrated,
        'soil_sample_available': sampleAvailable,
        'soil_raw': raw,
        'calibration_version': calibrationVersion,
        'sampled_at_ms': 120000,
        'recorded_at': sampledAt.toIso8601String(),
      };

  test('accepts fresh calibrated moisture and temperature readings', () {
    final result = PlantingSoilPrecheck.fromJson(readings());

    expect(result.isValid, isTrue);
    expect(result.soilMoisturePercent, 42.5);
    expect(result.soilTemperatureC, 24);
    expect(result.airTemperatureC, 25);
    expect(result.humidityPercent, 60);
    expect(
        result.isFreshAt(sampledAt.add(const Duration(seconds: 30))), isTrue);
  });

  test('diagnoses from raw reading and saved calibration references', () {
    final calibration = RoverCalibrationModel(
      secondsPerMeter: 1,
      soilDryRaw: 2100,
      soilWetRaw: 1050,
      rakeToGateCm: 10,
    );
    final nearPlantReady = PlantingSoilPrecheck.fromJson(
      readings(raw: 2100),
      calibration: calibration,
    );
    final tooWet = PlantingSoilPrecheck.fromJson(
      readings(raw: 1050),
      calibration: calibration,
    );

    expect(nearPlantReady.diagnosis.kind, SoilMoistureDiagnosisKind.good);
    expect(tooWet.diagnosis.kind, SoilMoistureDiagnosisKind.tooWet);
  });

  test('keeps diagnosis unavailable when references are absent', () {
    final result = PlantingSoilPrecheck.fromJson(readings());

    expect(result.isValid, isTrue);
    expect(result.diagnosis.kind, SoilMoistureDiagnosisKind.unavailable);
  });

  test('rejects uncalibrated moisture', () {
    final result = PlantingSoilPrecheck.fromJson(
      readings(calibrated: false, calibrationVersion: null),
    );

    expect(result.isValid, isFalse);
    expect(result.unavailableReason, contains('Calibrate'));
  });

  test('rejects unavailable moisture samples and invalid values', () {
    final missing = PlantingSoilPrecheck.fromJson(
      readings(sampleAvailable: false, raw: null, moisture: null),
    );
    final invalid = PlantingSoilPrecheck.fromJson(readings(moisture: 140));

    expect(missing.isValid, isFalse);
    expect(missing.unavailableReason, contains('unavailable'));
    expect(invalid.isValid, isFalse);
  });

  test('rejects missing or invalid soil temperature', () {
    final missing = PlantingSoilPrecheck.fromJson(readings(temperature: null));
    final invalid = PlantingSoilPrecheck.fromJson(readings(temperature: -127));

    expect(missing.isValid, isFalse);
    expect(missing.unavailableReason, contains('temperature'));
    expect(invalid.isValid, isFalse);
  });

  test('rejects stale or future-dated readings', () {
    final result = PlantingSoilPrecheck.fromJson(readings());

    expect(
        result.isFreshAt(sampledAt.add(const Duration(minutes: 2))), isFalse);
    expect(result.isFreshAt(sampledAt.subtract(const Duration(seconds: 1))),
        isFalse);
  });
}
