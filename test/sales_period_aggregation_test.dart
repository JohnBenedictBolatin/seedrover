import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/features/inventory/data/models/sales_period_aggregation.dart';

void main() {
  group('aggregateSalesPeriods', () {
    final asOf = DateTime.utc(2026, 9, 29, 4); // 12:00 in Manila.

    test(
        'counts completed receipt totals once and excludes voids and future records',
        () {
      final summary = aggregateSalesPeriods(
        asOf: asOf,
        standaloneSales: [
          SalesAggregateRecord(
            id: 'sale-1',
            date: DateTime.utc(2026, 9, 29, 2),
            total: 20,
            quantity: 2,
            status: 'Completed',
          ),
          SalesAggregateRecord(
            id: 'sale-void',
            date: DateTime.utc(2026, 9, 29, 3),
            total: 100,
            quantity: 10,
            status: 'Voided',
          ),
          SalesAggregateRecord(
            id: 'sale-future',
            date: DateTime.utc(2026, 9, 29, 5),
            total: 50,
            quantity: 5,
            status: 'Completed',
          ),
        ],
        receipts: [
          SalesAggregateRecord(
            id: 'receipt-1',
            date: DateTime.utc(2026, 9, 29, 1),
            total: 80, // Header total already reflects receipt discount.
            status: 'Completed',
          ),
          SalesAggregateRecord(
            id: 'receipt-1',
            date: DateTime.utc(2026, 9, 29, 1),
            total: 80,
            status: 'Completed',
          ),
          SalesAggregateRecord(
            id: 'receipt-zero',
            date: DateTime.utc(2026, 9, 28, 4),
            total: 0,
            status: 'Completed',
          ),
          SalesAggregateRecord(
            id: 'receipt-void',
            date: DateTime.utc(2026, 9, 28, 4),
            total: 999,
            status: 'Voided',
          ),
        ],
        receiptLines: [
          SalesReceiptLineCount(
            receiptId: 'receipt-1',
            date: DateTime.utc(2026, 9, 29, 1),
            quantity: 3,
            status: 'Completed',
          ),
          SalesReceiptLineCount(
            receiptId: 'receipt-1',
            date: DateTime.utc(2026, 9, 29, 1),
            quantity: 4,
            status: 'Completed',
          ),
          SalesReceiptLineCount(
            receiptId: 'receipt-void',
            date: DateTime.utc(2026, 9, 28, 4),
            quantity: 7,
            status: 'Voided',
          ),
        ],
      );

      expect(summary.salesToday, 100);
      expect(summary.salesThisWeek, 100);
      expect(summary.salesThisMonth, 100);
      expect(summary.salesThisYear, 100);
      expect(
          summary.salesTransactions, 3); // Includes the genuine zero receipt.
      expect(summary.salesTransactionsToday, 2);
      expect(summary.unitsSoldThisMonth, 9);
    });

    test('aggregates a complete dataset larger than 1,000 records', () {
      final records = List.generate(
        1001,
        (index) => SalesAggregateRecord(
          id: 'sale-$index',
          date: DateTime.utc(2026, 9, 29, 1),
          total: 1,
          quantity: 1,
          status: 'Completed',
        ),
      );

      final summary = aggregateSalesPeriods(
        asOf: asOf,
        standaloneSales: records,
        receipts: [],
        receiptLines: [],
      );

      expect(summary.salesToday, 1001);
      expect(summary.salesThisMonth, 1001);
      expect(summary.salesTransactions, 1001);
      expect(summary.unitsSoldThisMonth, 1001);
    });
  });
}
