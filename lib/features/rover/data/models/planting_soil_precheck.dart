import '../../../../shared/models/soil_moisture_diagnosis.dart';
import 'planting_session_model.dart';

class PlantingSoilPrecheck {
  const PlantingSoilPrecheck({
    required this.soilMoisturePercent,
    required this.soilTemperatureC,
    this.airTemperatureC,
    this.humidityPercent,
    required this.sampledAt,
    required this.sampledAtMs,
    required this.moistureCalibrated,
    required this.soilSampleAvailable,
    required this.soilRaw,
    required this.dryReferenceRaw,
    required this.moistReferenceRaw,
    this.errorMessage,
  });

  factory PlantingSoilPrecheck.fromJson(
    Map<String, dynamic> json, {
    RoverCalibrationModel? calibration,
  }) {
    double? finiteNumber(Object? value, double min, double max) {
      final number = (value as num?)?.toDouble();
      return number != null && number.isFinite && number >= min && number <= max
          ? number
          : null;
    }

    final rawDate = DateTime.tryParse(json['recorded_at']?.toString() ?? '');
    final soilRaw =
        json['soil_raw'] is num ? (json['soil_raw'] as num).toInt() : null;
    return PlantingSoilPrecheck(
      soilMoisturePercent: finiteNumber(
        json['soil_moisture_percent'],
        0,
        100,
      ),
      soilTemperatureC: finiteNumber(json['soil_temperature_c'], -55, 125),
      // The rover uses a DHT11. Ignore values outside its operating range.
      airTemperatureC: finiteNumber(json['air_temperature_c'], 0, 50),
      humidityPercent: finiteNumber(json['humidity_percent'], 20, 90),
      sampledAt: rawDate?.toLocal(),
      sampledAtMs: (json['sampled_at_ms'] as num?)?.toInt(),
      moistureCalibrated: json['soil_moisture_calibrated'] == true &&
          (json['calibration_version']?.toString().trim().isNotEmpty ?? false),
      soilSampleAvailable: json['soil_sample_available'] == true &&
          soilRaw != null &&
          soilRaw > 0 &&
          soilRaw < 4095,
      soilRaw: soilRaw,
      dryReferenceRaw: calibration?.soilDryRaw,
      moistReferenceRaw: calibration?.soilWetRaw,
    );
  }

  const PlantingSoilPrecheck.unavailable(String message)
      : soilMoisturePercent = null,
        soilTemperatureC = null,
        airTemperatureC = null,
        humidityPercent = null,
        sampledAt = null,
        sampledAtMs = null,
        moistureCalibrated = false,
        soilSampleAvailable = false,
        soilRaw = null,
        dryReferenceRaw = null,
        moistReferenceRaw = null,
        errorMessage = message;

  final double? soilMoisturePercent;
  final double? soilTemperatureC;
  final double? airTemperatureC;
  final double? humidityPercent;
  final DateTime? sampledAt;
  final int? sampledAtMs;
  final bool moistureCalibrated;
  final bool soilSampleAvailable;
  final int? soilRaw;
  final int? dryReferenceRaw;
  final int? moistReferenceRaw;
  final String? errorMessage;

  SoilMoistureDiagnosis get diagnosis => !moistureCalibrated
      ? const SoilMoistureDiagnosis.unavailable()
      : SoilMoistureDiagnosis.fromRawReading(
          raw: soilRaw,
          dryReferenceRaw: dryReferenceRaw,
          moistReferenceRaw: moistReferenceRaw,
        );

  bool get isValid =>
      errorMessage == null &&
      soilSampleAvailable &&
      moistureCalibrated &&
      soilMoisturePercent != null &&
      soilTemperatureC != null &&
      sampledAt != null &&
      sampledAtMs != null;

  String get unavailableReason {
    if (errorMessage != null) return errorMessage!;
    if (!soilSampleAvailable) return 'Soil moisture reading is unavailable.';
    if (!moistureCalibrated || soilMoisturePercent == null) {
      return 'Calibrate the soil-moisture sensor before planting.';
    }
    if (soilTemperatureC == null) {
      return 'Soil temperature reading is unavailable.';
    }
    if (sampledAt == null) return 'Reading time is unavailable.';
    if (sampledAtMs == null) return 'Sensor sample reference is unavailable.';
    return 'Soil readings are ready to review.';
  }

  bool isFreshAt(DateTime now,
      {Duration maxAge = const Duration(seconds: 60)}) {
    final captured = sampledAt;
    if (captured == null) return false;
    final age = now.difference(captured);
    return age >= Duration.zero && age <= maxAge;
  }
}
