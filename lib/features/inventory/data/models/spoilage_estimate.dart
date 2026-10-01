import 'stock_model.dart';

class SpoilageProfile {
  const SpoilageProfile({
    required this.id,
    required this.label,
    required this.days,
    required this.source,
    required this.sourceTitle,
    required this.conditions,
    this.limitation = '',
  });

  final String id;
  final String label;
  final int days;
  final String source;
  final String sourceTitle;
  final String conditions;
  final String limitation;
}

DateTime manilaCalendarDate([DateTime? instant]) {
  final manila =
      (instant ?? DateTime.now()).toUtc().add(const Duration(hours: 8));
  return DateTime.utc(manila.year, manila.month, manila.day);
}

class BatchSpoilageEstimate {
  const BatchSpoilageEstimate({
    required this.profile,
    required this.estimatedDate,
    required this.remainingDays,
    required this.startDate,
  });

  final SpoilageProfile profile;
  final DateTime estimatedDate;
  final int remainingDays;
  final DateTime startDate;
}

/// Uses the estimate date and reference snapshot returned by the database.
/// Clients only calculate the countdown against the current Philippine date.
BatchSpoilageEstimate? estimateStockBatch(
  InventoryStockBatch batch, {
  DateTime? today,
}) {
  final estimatedDate = batch.estimatedSpoilageOn;
  final profileName = batch.profileName;
  if (!batch.ageKnown || estimatedDate == null || profileName == null) {
    return null;
  }

  final profile = SpoilageProfile(
    id: batch.profileId ?? '',
    label: profileName,
    days: batch.referenceDays ?? 0,
    source: batch.referenceSource ?? '',
    sourceTitle: batch.referenceSourceTitle ?? '',
    conditions: batch.referenceConditions ?? '',
    limitation: batch.referenceNote ?? '',
  );
  final startDate = batch.harvestOn ?? batch.receivedOn;
  final currentDate = manilaCalendarDate(today);
  final estimateDate =
      DateTime.utc(estimatedDate.year, estimatedDate.month, estimatedDate.day);
  return BatchSpoilageEstimate(
    profile: profile,
    estimatedDate: estimateDate,
    remainingDays: estimateDate.difference(currentDate).inDays,
    startDate: startDate,
  );
}
