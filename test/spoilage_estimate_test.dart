import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/features/inventory/data/models/spoilage_estimate.dart';
import 'package:seedrover/features/inventory/data/models/stock_model.dart';

void main() {
  group('inventory spoilage estimates', () {
    test('uses the database estimate and harvest date basis', () {
      final batch = InventoryStockBatch(
        id: 'batch-1',
        originType: 'harvest',
        initialQuantity: 4,
        remainingQuantity: 2,
        receivedOn: DateTime.utc(2026, 10, 1),
        harvestOn: DateTime.utc(2026, 10, 3),
        ageKnown: true,
        profileId: 'pechay',
        profileName: 'Pechay (25-day crowns)',
        dateBasis: 'Harvest date',
        estimatedSpoilageOn: DateTime.utc(2026, 10, 5),
        referenceDays: 2,
        referenceSourceTitle: 'NAST Philippines study',
      );

      final estimate = estimateStockBatch(
        batch,
        today: DateTime.utc(2026, 10, 4),
      );

      expect(estimate?.estimatedDate, DateTime.utc(2026, 10, 5));
      expect(estimate?.remainingDays, 1);
      expect(estimate?.startDate, DateTime.utc(2026, 10, 3));
    });

    test('keeps unknown-age and unsupported-product batches unestimated', () {
      InventoryStockBatch makeBatch(
              {required bool ageKnown,
              String? profileId,
              DateTime? estimatedOn}) =>
          InventoryStockBatch(
            id: 'batch',
            originType: 'historical',
            initialQuantity: 1,
            remainingQuantity: 1,
            receivedOn: DateTime.utc(2026, 10, 1),
            ageKnown: ageKnown,
            profileId: profileId,
            profileName: estimatedOn == null ? null : 'Pechay (25-day crowns)',
            estimatedSpoilageOn: estimatedOn,
          );

      expect(
          estimateStockBatch(makeBatch(ageKnown: false, profileId: 'pechay')),
          isNull);
      expect(estimateStockBatch(makeBatch(ageKnown: true, profileId: null)),
          isNull);
      expect(
        estimateStockBatch(makeBatch(
          ageKnown: true,
          profileId: 'pechay',
          estimatedOn: DateTime.utc(2026, 10, 5),
        )),
        isNotNull,
      );
    });

    test('uses the database estimate date rather than a client catalogue', () {
      final estimate = estimateStockBatch(
        InventoryStockBatch(
          id: 'batch-versioned',
          originType: 'receipt',
          initialQuantity: 1,
          remainingQuantity: 1,
          receivedOn: DateTime.utc(2026, 10, 1),
          ageKnown: true,
          profileId: 'pechay',
          profileName: 'Pechay (reference v2)',
          referenceDays: 4,
          estimatedSpoilageOn: DateTime.utc(2026, 10, 8),
        ),
        today: DateTime.utc(2026, 10, 2),
      );

      expect(estimate?.estimatedDate, DateTime.utc(2026, 10, 8));
      expect(estimate?.remainingDays, 6);
    });

    test('rolls to the next Philippine calendar day at UTC 16:00', () {
      expect(
        manilaCalendarDate(DateTime.utc(2026, 10, 1, 15, 59)),
        DateTime.utc(2026, 10, 1),
      );
      expect(
        manilaCalendarDate(DateTime.utc(2026, 10, 1, 16)),
        DateTime.utc(2026, 10, 2),
      );
    });
  });
}
