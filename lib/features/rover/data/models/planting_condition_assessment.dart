import 'dart:math' as math;

import '../../../../shared/models/soil_moisture_diagnosis.dart';
import 'planting_soil_precheck.dart';
import 'rover_command_model.dart';

/// Local farmer-facing advice. A score is the share of supported soil checks
/// that match the cited guidance; it is not a probability of crop success.
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
        temperatureGuidance = 'Peanut reference: 20–30°C soil temperature.';
        if (soilTemp == null) {
          temperatureAdvice =
              'Soil temperature is unavailable. Retry the soil check.';
        } else if (soilTemp < 18) {
          temperatureMatches = false;
          temperatureAdvice =
              'Soil is below 18°C, where peanut germination faces stronger cold-soil concern. Recheck after the soil warms.';
        } else if (soilTemp < 20) {
          temperatureMatches = false;
          temperatureAdvice =
              'Soil is cooler than the cited 20–30°C peanut range. Recheck after the soil warms.';
        } else if (soilTemp <= 30) {
          temperatureMatches = true;
          temperatureAdvice =
              'Soil temperature is within the cited peanut germination range.';
        } else {
          temperatureMatches = false;
          temperatureAdvice =
              'This reading is above the cited peanut range. Verify seed-specific guidance before deciding.';
        }
        break;
      case PlantingSeedType.sitaw:
        temperatureGuidance =
            'Sitaw reference: soil above 22°C supports germination; a full upper range is not established here.';
        if (soilTemp == null) {
          temperatureAdvice =
              'Soil temperature is unavailable. Retry the soil check.';
        } else if (soilTemp <= 22) {
          temperatureAdvice =
              'Soil has not exceeded the published 22°C warm-soil reference. Recheck after it warms.';
        } else {
          temperatureAdvice =
              'Soil exceeds the published 22°C minimum reference. A full sitaw temperature range is not established, so this is not scored.';
        }
        limitations.add(
            'Sitaw guidance provides a warm-soil reference, not a full temperature range.');
        break;
      case PlantingSeedType.calamansi:
        temperatureGuidance =
            'A crop-specific direct-seeding soil-temperature range is not established.';
        temperatureAdvice = soilTemp == null
            ? 'Soil temperature is unavailable. Retry the soil check.'
            : 'Measured soil temperature is ${soilTemp.toStringAsFixed(1)}°C. A crop-specific direct-seeding range is not established, so no temperature verdict is given.';
        limitations.add(
            'Calamansi direct-seeding temperature guidance is incomplete; another citrus profile is not substituted.');
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
        ? 'Assessment incomplete'
        : score == 100
            ? 'Current soil checks match'
            : 'Conditions need attention';

    if (!envAvailable) {
      limitations.add(
          'Air temperature and humidity are required for a complete assessment and Conditions match percentage.');
    }
    if (!fresh) {
      limitations.add(
          'This pre-check is older than 60 seconds. Retry before proceeding.');
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
