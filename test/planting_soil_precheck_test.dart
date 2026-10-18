import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/features/rover/data/models/planting_soil_precheck.dart';

void main() {
  final capturedAt = DateTime.now().toUtc();

  test('accepts only current, calibrated readings with trusted provenance', () {
    final readings = PlantingSoilPrecheck.fromJson({
      'recorded_at': capturedAt.toIso8601String(),
      'sampled_at_ms': 12000,
      'sensor_provenance_version': 1,
      'soil_reading_source': 'measured',
      'soil_sample_available': true,
      'soil_raw': 1800,
      'soil_moisture_percent': 47.5,
      'soil_moisture_calibrated': true,
      'calibration_version': 'soil-linear-v1',
      'soil_temperature_c': 23.4,
    });

    expect(readings.provenanceVerified, isTrue);
    expect(readings.isValid, isTrue);
    expect(readings.allowUnavailableSoil, isFalse);
  });

  test('keeps a successful but missing-reading pre-check nullable', () {
    final readings = PlantingSoilPrecheck.fromJson({
      'recorded_at': capturedAt.toIso8601String(),
      'sampled_at_ms': 12000,
      'sensor_provenance_version': 1,
      'soil_reading_source': 'unavailable',
      'soil_sample_available': false,
      'soil_raw': null,
      'soil_moisture_percent': null,
      'soil_moisture_calibrated': false,
      'soil_temperature_c': null,
    });
    final accepted = readings.copyWith(allowUnavailableSoil: true);

    expect(readings.isFreshAt(DateTime.now()), isTrue);
    expect(readings.isValid, isFalse);
    expect(readings.soilRaw, isNull);
    expect(readings.soilMoisturePercent, isNull);
    expect(readings.soilTemperatureC, isNull);
    expect(accepted.allowUnavailableSoil, isTrue);
    expect(accepted.isValid, isFalse);
  });

  test('does not let an explicit override bypass a connection error', () {
    final failed = const PlantingSoilPrecheck.unavailable(
      'The rover could not be reached.',
    ).copyWith(allowUnavailableSoil: true);

    expect(failed.allowUnavailableSoil, isTrue);
    expect(failed.errorMessage, 'The rover could not be reached.');
    expect(failed.isFreshAt(DateTime.now()), isFalse);
    expect(failed.isValid, isFalse);
  });
}
