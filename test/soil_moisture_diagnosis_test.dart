import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/shared/models/soil_moisture_diagnosis.dart';

void main() {
  const dry = 2100;
  const moist = 1050;

  int rawAt(double relativePercent) =>
      (dry - relativePercent * (dry - moist) / 100).round();

  SoilMoistureDiagnosis diagnose(double relativePercent) =>
      SoilMoistureDiagnosis.fromRawReading(
        raw: rawAt(relativePercent),
        dryReferenceRaw: dry,
        moistReferenceRaw: moist,
      );

  test('gives a direct planting recommendation from the reference bands', () {
    expect(diagnose(-10).kind, SoilMoistureDiagnosisKind.good);
    expect(diagnose(0).kind, SoilMoistureDiagnosisKind.good);
    expect(diagnose(10).kind, SoilMoistureDiagnosisKind.good);
    expect(diagnose(-11).kind, SoilMoistureDiagnosisKind.tooDry);
    expect(diagnose(10.1).kind, SoilMoistureDiagnosisKind.tooWet);
    expect(diagnose(89.9).kind, SoilMoistureDiagnosisKind.tooWet);
    expect(diagnose(90).kind, SoilMoistureDiagnosisKind.tooWet);
    expect(diagnose(110).kind, SoilMoistureDiagnosisKind.tooWet);
    expect(diagnose(0).label, 'Moisture is in the plant-ready range');
    expect(diagnose(-11).label, 'Too dry');
    expect(diagnose(11).label, 'Too wet');
  });

  test('handles reversed sensor endpoint direction', () {
    final result = SoilMoistureDiagnosis.fromRawReading(
      raw: 1500,
      dryReferenceRaw: 1000,
      moistReferenceRaw: 2000,
    );

    expect(result.kind, SoilMoistureDiagnosisKind.tooWet);
    expect(result.extendedPercent, 50);
  });

  test('does not diagnose missing or invalid raw references', () {
    SoilMoistureDiagnosis diagnoseInvalid({
      int? raw = 1800,
      int? dryReferenceRaw = dry,
      int? moistReferenceRaw = moist,
    }) =>
        SoilMoistureDiagnosis.fromRawReading(
          raw: raw,
          dryReferenceRaw: dryReferenceRaw,
          moistReferenceRaw: moistReferenceRaw,
        );

    expect(
        diagnoseInvalid(raw: null).kind, SoilMoistureDiagnosisKind.unavailable);
    expect(diagnoseInvalid(raw: 0).kind, SoilMoistureDiagnosisKind.unavailable);
    expect(diagnoseInvalid(dryReferenceRaw: 0).kind,
        SoilMoistureDiagnosisKind.unavailable);
    expect(diagnoseInvalid(dryReferenceRaw: moist).kind,
        SoilMoistureDiagnosisKind.unavailable);
    expect(diagnoseInvalid(moistReferenceRaw: 4095).kind,
        SoilMoistureDiagnosisKind.unavailable);
    expect(diagnoseInvalid(dryReferenceRaw: 4096).kind,
        SoilMoistureDiagnosisKind.unavailable);
  });
}
