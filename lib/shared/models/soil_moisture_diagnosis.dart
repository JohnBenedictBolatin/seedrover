enum SoilMoistureDiagnosisKind {
  good,
  tooDry,
  tooWet,
  unavailable,
}

class SoilMoistureDiagnosis {
  const SoilMoistureDiagnosis._({
    required this.kind,
    required this.extendedPercent,
  });

  factory SoilMoistureDiagnosis.fromRawReading({
    required int? raw,
    required int? dryReferenceRaw,
    required int? moistReferenceRaw,
  }) {
    if (raw == null || raw <= 0 || raw >= 4095) {
      return const SoilMoistureDiagnosis.unavailable();
    }
    if (dryReferenceRaw == null ||
        moistReferenceRaw == null ||
        dryReferenceRaw <= 0 ||
        dryReferenceRaw >= 4095 ||
        moistReferenceRaw <= 0 ||
        moistReferenceRaw >= 4095 ||
        dryReferenceRaw == moistReferenceRaw) {
      return const SoilMoistureDiagnosis.unavailable();
    }

    final span = dryReferenceRaw - moistReferenceRaw;
    final percent = 100 * (dryReferenceRaw - raw) / span;
    if (!percent.isFinite) {
      return const SoilMoistureDiagnosis.unavailable();
    }

    // The plant-ready sample is the target. Readings outside its 10% tolerance
    // are classified directly against that target, including the full span
    // toward the farmer's wet-soil reference.
    final kind = percent < -10
        ? SoilMoistureDiagnosisKind.tooDry
        : percent <= 10
            ? SoilMoistureDiagnosisKind.good
            : SoilMoistureDiagnosisKind.tooWet;
    return SoilMoistureDiagnosis._(
      kind: kind,
      extendedPercent: percent,
    );
  }

  const SoilMoistureDiagnosis.unavailable()
      : kind = SoilMoistureDiagnosisKind.unavailable,
        extendedPercent = null;

  final SoilMoistureDiagnosisKind kind;
  final double? extendedPercent;

  String get label => switch (kind) {
        SoilMoistureDiagnosisKind.good => 'Good for planting',
        SoilMoistureDiagnosisKind.tooDry => 'Too dry',
        SoilMoistureDiagnosisKind.tooWet => 'Too wet',
        SoilMoistureDiagnosisKind.unavailable => 'Diagnosis unavailable',
      };
}
