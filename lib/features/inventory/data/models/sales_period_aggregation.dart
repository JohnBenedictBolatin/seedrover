import '../../../../core/utils/business_calendar.dart';
import 'stock_model.dart';

class SalesAggregateRecord {
  const SalesAggregateRecord({
    required this.id,
    required this.date,
    required this.total,
    required this.status,
    this.quantity = 0,
  });

  final String id;
  final DateTime date;
  final double total;
  final String status;
  final double quantity;
}

class SalesReceiptLineCount {
  const SalesReceiptLineCount({
    required this.receiptId,
    required this.date,
    required this.quantity,
    required this.status,
  });

  final String receiptId;
  final DateTime date;
  final double quantity;
  final String status;
}

StockSalesSummaryModel aggregateSalesPeriods({
  required List<SalesAggregateRecord> standaloneSales,
  required List<SalesAggregateRecord> receipts,
  required List<SalesReceiptLineCount> receiptLines,
  required DateTime asOf,
}) {
  final todayStart = BusinessCalendar.startOfDay(asOf);
  final tomorrowStart = todayStart.add(const Duration(days: 1));
  final weekStart = BusinessCalendar.startOfWeek(asOf);
  final monthStart = BusinessCalendar.startOfMonth(asOf);
  final nextMonthStart = BusinessCalendar.startOfNextMonth(asOf);
  final yearStart = BusinessCalendar.startOfYear(asOf);
  final nextYearStart = BusinessCalendar.startOfNextYear(asOf);

  var today = 0.0;
  var week = 0.0;
  var month = 0.0;
  var year = 0.0;
  var unitsThisMonth = 0.0;
  var monthTransactions = 0;
  var todayTransactions = 0;
  var weekTransactions = 0;
  var yearTransactions = 0;

  void addSale(
      {required DateTime date,
      required double total,
      required double quantity}) {
    final occurredAt = date.toUtc();
    if (occurredAt.isAfter(asOf.toUtc())) return;
    if (!occurredAt.isBefore(yearStart) && occurredAt.isBefore(nextYearStart)) {
      year += total;
      yearTransactions++;
    }
    if (!occurredAt.isBefore(weekStart) && occurredAt.isBefore(tomorrowStart)) {
      week += total;
      weekTransactions++;
    }
    if (!occurredAt.isBefore(monthStart) &&
        occurredAt.isBefore(nextMonthStart)) {
      month += total;
      unitsThisMonth += quantity;
      monthTransactions++;
    }
    if (!occurredAt.isBefore(todayStart) &&
        occurredAt.isBefore(tomorrowStart)) {
      today += total;
      todayTransactions++;
    }
  }

  final seenStandaloneIds = <String>{};
  for (final record in standaloneSales) {
    if (record.id.isNotEmpty && !seenStandaloneIds.add(record.id)) continue;
    if (record.status == 'Completed') {
      addSale(
          date: record.date, total: record.total, quantity: record.quantity);
    }
  }
  final seenReceiptIds = <String>{};
  for (final record in receipts) {
    if (record.id.isNotEmpty && !seenReceiptIds.add(record.id)) continue;
    if (record.status == 'Completed') {
      // Parent receipt total is authoritative and already includes discounts.
      addSale(date: record.date, total: record.total, quantity: 0);
    }
  }
  for (final line in receiptLines) {
    final occurredAt = line.date.toUtc();
    if (line.status == 'Completed' &&
        !occurredAt.isAfter(asOf.toUtc()) &&
        !occurredAt.isBefore(monthStart.toUtc()) &&
        occurredAt.isBefore(nextMonthStart.toUtc())) {
      unitsThisMonth += line.quantity;
    }
  }

  return StockSalesSummaryModel(
    salesToday: today,
    salesThisWeek: week,
    salesThisMonth: month,
    salesThisYear: year,
    unitsSoldThisMonth: unitsThisMonth,
    salesTransactions: monthTransactions,
    salesTransactionsToday: todayTransactions,
    salesTransactionsThisWeek: weekTransactions,
    salesTransactionsThisYear: yearTransactions,
  );
}
