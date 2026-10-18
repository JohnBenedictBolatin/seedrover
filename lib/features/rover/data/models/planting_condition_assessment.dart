import 'dart:math' as math;

import '../../../../shared/models/soil_moisture_diagnosis.dart';
import 'planting_soil_precheck.dart';
import 'rover_command_model.dart';

/// Local farmer-facing advice. A score counts soil checks that match available
/// guidance; it does not predict whether a crop will grow successfully.
class PlantingConditionAssessment {
  static const ruleVersion = '2026-09-v1';

  const PlantingConditionAssessment({
    required this.summary,
    required this.moistureAdvice,
    required this.soilTemperatureAdvice,
    required this.environmentAdvice,
    required this.score,
    required this.matchedChecks,
    required this.checkCount,
    required this.isComplete,
    required this.hasMoistureConcern,
    required this.vaporPressureDeficitKpa,
    required this.temperatureGuidance,
    required this.limitations,
  });

  final String summary;
  final String moistureAdvice;
  final String soilTemperatureAdvice;
  final String environmentAdvice;
  final int? score;
  final int? matchedChecks;
  final int checkCount;
  final bool isComplete;
  final bool hasMoistureConcern;
  final double? vaporPressureDeficitKpa;
  final String temperatureGuidance;
  final List<String> limitations;

  factory PlantingConditionAssessment.evaluate({
    required PlantingSeedType seed,
    required PlantingSoilPrecheck readings,
    required DateTime assessedAt,
  }) {
    final diagnosis = readings.diagnosis;
    final moistureMatches = diagnosis.kind == SoilMoistureDiagnosisKind.good;
    final moistureAvailable =
        diagnosis.kind != SoilMoistureDiagnosisKind.unavailable;
    final moistureConcern =
        diagnosis.kind == SoilMoistureDiagnosisKind.tooDry ||
            diagnosis.kind == SoilMoistureDiagnosisKind.tooWet;
    final moistureAdvice = diagnosis.label;

    final soilTemp = readings.soilTemperatureC;
    bool? temperatureMatches;
    late final String temperatureAdvice;
    late final String temperatureGuidance;
    final limitations = <String>[];
    switch (seed) {
      case PlantingSeedType.peanut:
        temperatureGuidance = 'Suggested soil temperature for peanuts: 20–30°C.';
        if (soilTemp == null) {
          temperatureAdvice =
              'Soil temperature is unavailable. Retry the soil check.';
        } else if (soilTemp < 18) {
          temperatureMatches = false;
          temperatureAdvice =
              'The soil is below 18°C. Wait for it to warm before planting peanuts.';
        } else if (soilTemp < 20) {
          temperatureMatches = false;
          temperatureAdvice =
              'The soil is cooler than the suggested range for peanuts. Check again after it warms.';
        } else if (soilTemp <= 30) {
          temperatureMatches = true;
          temperatureAdvice =
              'The soil is within the suggested temperature range for peanuts.';
        } else {
          temperatureMatches = false;
          temperatureAdvice =
              'The soil is warmer than the suggested range for peanuts. Check local planting advice before deciding.';
        }
        break;
      case PlantingSeedType.sitaw:
        temperatureGuidance =
            'Available guidance suggests planting sitaw when the soil is above 22°C. An upper limit is not known.';
        if (soilTemp == null) {
          temperatureAdvice =
              'Soil temperature is unavailable. Retry the soil check.';
        } else if (soilTemp <= 22) {
          temperatureAdvice =
              'The soil is not warmer than 22°C yet. Check again after it warms.';
        } else {
          temperatureAdvice =
              'The soil is warmer than 22°C. Available guidance does not give a full temperature range for sitaw, so no score is shown.';
        }
        limitations.add(
            'Available sitaw guidance gives a minimum temperature, but no upper limit.');
        break;
      case PlantingSeedType.calamansi:
        temperatureGuidance =
            'There is no confirmed soil-temperature range for planting calamansi seeds directly.';
        temperatureAdvice = soilTemp == null
            ? 'Soil temperature is unavailable. Retry the soil check.'
            : 'Soil temperature is ${soilTemp.toStringAsFixed(1)}°C. There is no confirmed temperature range for planting calamansi seeds directly, so no advice is available.';
        limitations.add(
            'There is not enough confirmed temperature guidance for planting calamansi seeds directly.');
        break;
    }

    final airTemp = readings.airTemperatureC;
    final humidity = readings.humidityPercent;
    final envAvailable = airTemp != null && humidity != null;
    final vpd = envAvailable ? calculateVpdKpa(airTemp, humidity) : null;
    final environmentAdvice = !envAvailable
        ? 'Air temperature or humidity is unavailable, so the environmental cross-check is incomplete.'
        : 'Air temperature and humidity are read together to describe current conditions around this planting spot.';

    final fresh = readings.isFreshAt(assessedAt);
    final coreAvailable = readings.isValid &&
        fresh &&
        moistureAvailable &&
        temperatureMatches != null;
    final scoringSupported = seed == PlantingSeedType.peanut;
    final complete = coreAvailable && envAvailable && scoringSupported;
    final matched = coreAvailable
        ? (moistureMatches ? 1 : 0) + (temperatureMatches ? 1 : 0)
        : null;
    final score = complete && matched != null ? matched * 50 : null;
    final summary = !complete
        ? 'Soil check incomplete'
        : score == 100
            ? 'Soil checks look good'
            : 'Check the soil before planting';

    if (!envAvailable) {
      limitations.add(
          'Air temperature and humidity are needed before the app can show a complete check and match percentage.');
    }
    if (!fresh) {
      limitations.add(
          'This soil reading is over a minute old. Check the soil again before planting.');
    }
    limitations.add(
        'The percentage counts supported checks only; it is not a probability of germination or harvest success.');
    limitations.add(
        'Air temperature and humidity provide current atmospheric context only. They do not predict future weather or diagnose watering, disease, or drainage needs.');

    return PlantingConditionAssessment(
      summary: summary,
      moistureAdvice: moistureAdvice,
      soilTemperatureAdvice: temperatureAdvice,
      environmentAdvice: environmentAdvice,
      score: score,
      matchedChecks: complete ? matched : null,
      checkCount: 2,
      isComplete: complete,
      hasMoistureConcern: moistureConcern,
      vaporPressureDeficitKpa: vpd,
      temperatureGuidance: temperatureGuidance,
      limitations: limitations,
    );
  }

  /// FAO saturation-vapour-pressure equation; result is instantaneous VPD.
  static double? calculateVpdKpa(double temperatureC, double relativeHumidity) {
    if (!temperatureC.isFinite ||
        temperatureC < 0 ||
        temperatureC > 50 ||
        !relativeHumidity.isFinite ||
        relativeHumidity < 0 ||
        relativeHumidity > 100) {
      return null;
    }
    final saturation =
        0.6108 * math.exp((17.27 * temperatureC) / (temperatureC + 237.3));
    final actual = saturation * relativeHumidity / 100;
    final value = saturation - actual;
    return value.isFinite ? math.max(0, value) : null;
  }
}
