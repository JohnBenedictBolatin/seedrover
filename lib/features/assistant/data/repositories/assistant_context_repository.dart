import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../crops/data/models/crop_model.dart';
import '../../../crops/providers/crop_providers.dart';
import '../../../dashboard/providers/dashboard_providers.dart';
import '../../../inventory/data/models/stock_model.dart';
import '../../../inventory/providers/stock_providers.dart';
import '../../../../core/utils/business_calendar.dart';
import '../models/assistant_context_model.dart';

final assistantContextProvider = Provider<AssistantContextModel>((ref) {
  final cropState = ref.watch(cropMonitoringControllerProvider);
  final stockState = ref.watch(stockInventoryControllerProvider);
  final dashboard = ref.watch(dashboardProvider).maybeWhen(
        data: (value) => value,
        orElse: () => null,
      );
  final rover = dashboard?.rover;

  return AssistantContextModel(
    generatedAt: DateTime.now(),
    rover: rover == null
        ? const {}
        : {
            'unitName': rover.unitName,
            'status': rover.status,
            'plantingStatus': rover.plantingStatus,
            'wifiConnected': rover.wifiConnected,
            'bluetoothConnected': rover.bluetoothConnected,
            'cameraConnected': rover.cameraConnected,
            'isInUse': rover.isInUse,
            'lastCommunication': rover.lastCommunication?.toIso8601String(),
          },
    crops: [
      for (final crop in cropState.crops.take(12)) _cropContext(crop),
    ],
    stocks: [
      for (final stock in stockState.stocks.take(12)) _stockContext(stock),
    ],
    recentActivities: [
      for (final activity in (dashboard?.recentActivities ?? const []).take(8))
        {
          'title': activity.title,
          'description': activity.description,
          'module': activity.module,
          'timestamp': activity.timestamp?.toIso8601String(),
        },
    ],
    farmAnalytics: _farmAnalyticsContext(
      crops: cropState.crops,
      stocks: stockState.stocks,
      salesSummary: stockState.salesSummary,
      salesSummaryAvailable: stockState.hasSalesSummary,
      salesSummaryError: stockState.salesSummaryError,
    ),
  );
});

Map<String, dynamic> _cropContext(CropModel crop) {
  final latestWatering = crop.maintenanceHistory
      .where((record) => record.activity == CropMaintenanceActivity.watered)
      .toList()
    ..sort((left, right) => right.performedAt.compareTo(left.performedAt));

  return {
    'name': crop.name,
    'variety': crop.variety,
    'field': crop.fieldLabel,
    'plantingDate': crop.plantingDate.toIso8601String(),
    'growthStage': crop.growthStageLabel,
    'status': crop.status.label,
    'careStatus': crop.careStatus,
    'lastWateredAt': crop.lastWateredAt?.toIso8601String() ??
        (latestWatering.isEmpty
            ? null
            : latestWatering.first.performedAt.toIso8601String()),
  };
}

Map<String, dynamic> _stockContext(StockModel stock) {
  final latestStockIn = stock.transactions
      .where((transaction) => transaction.type == StockTransactionType.stockIn)
      .toList()
    ..sort((left, right) => right.performedAt.compareTo(left.performedAt));

  return {
    'name': stock.name,
    'category': stock.category.label,
    'quantity': stock.currentQuantity,
    'unit': stock.unit,
    'status': stock.status.label,
    'minimumStockLevel': stock.minimumStockLevel,
    'quantitySold': stock.quantitySold,
    'lastSaleDate': stock.lastSaleDate?.toIso8601String(),
    'lastUpdated': stock.lastUpdated.toIso8601String(),
    'lastRestockedAt': latestStockIn.isEmpty
        ? null
        : latestStockIn.first.performedAt.toIso8601String(),
    'recentSales': [
      for (final sale in stock.sales
          .where((sale) => sale.status == SalesTransactionStatus.completed)
          .take(5))
        {
          'quantitySold': sale.quantitySold,
          'saleDate': sale.saleDate.toIso8601String(),
        },
    ],
  };
}

Map<String, dynamic> _farmAnalyticsContext({
  required List<CropModel> crops,
  required List<StockModel> stocks,
  required StockSalesSummaryModel salesSummary,
  required bool salesSummaryAvailable,
  required String? salesSummaryError,
}) {
  final assessmentNow = BusinessCalendar.now();
  final monthlySales = <String, double>{};
  final monthlyPlanting = <String, int>{};
  final soldByItem = <String, double>{};
  final salesAmountByItem = <String, double>{};
  final plantedByCrop = <String, int>{};
  final stockOutTransactions = <Map<String, dynamic>>[];
  final salesTransactions = <Map<String, dynamic>>[];
  var stockOutCount = 0;
  final saleIds = <String>{};

  for (final crop in crops) {
    if (crop.plantingDate.toUtc().isAfter(assessmentNow)) continue;
    final monthKey = _monthKey(crop.plantingDate);
    monthlyPlanting.update(monthKey, (value) => value + 1, ifAbsent: () => 1);
    plantedByCrop.update(crop.name, (value) => value + 1, ifAbsent: () => 1);
  }

  for (final stock in stocks) {
    for (final sale in stock.sales) {
      if (sale.status != SalesTransactionStatus.completed) {
        continue;
      }
      if (sale.saleDate.toUtc().isAfter(assessmentNow)) continue;

      final monthKey = _monthKey(sale.saleDate);
      saleIds.add(sale.id);
      monthlySales.update(
        monthKey,
        (value) => value + sale.totalAmount,
        ifAbsent: () => sale.totalAmount,
      );
      final itemLabel = '${stock.name} (${stock.unit})';
      soldByItem.update(
        itemLabel,
        (value) => value + sale.quantitySold,
        ifAbsent: () => sale.quantitySold,
      );
      salesAmountByItem.update(
        itemLabel,
        (value) => value + sale.totalAmount,
        ifAbsent: () => sale.totalAmount,
      );
      salesTransactions.add({
        'item': itemLabel,
        'quantity': sale.quantitySold,
        'unit': stock.unit,
        'itemLineTotalBeforeReceiptDiscounts': sale.totalAmount,
        'date': sale.saleDate.toIso8601String(),
      });
    }

    for (final transaction in stock.transactions) {
      if (transaction.type != StockTransactionType.stockOut) {
        continue;
      }
      if (transaction.performedAt.toUtc().isAfter(assessmentNow)) continue;

      stockOutCount += 1;
      stockOutTransactions.add({
        'item': stock.name,
        'quantity': transaction.quantity,
        'unit': stock.unit,
        'date': transaction.performedAt.toIso8601String(),
      });
    }
  }

  final realSalesCount = saleIds.length;
  final totalSalesAmount = salesSummary.salesThisYear;
  final salesByMonth = _sortedDoubleEntries(monthlySales);
  final plantingByMonth = _sortedIntEntries(monthlyPlanting);
  final topSoldItems = _sortedDoubleEntries(soldByItem);
  final topSalesValueItems = _sortedDoubleEntries(salesAmountByItem);
  final topPlantedCrops = _sortedIntEntries(plantedByCrop);
  final bestSalesMonth = salesByMonth.isEmpty ? null : salesByMonth.first;
  final recentSales = [...salesTransactions]
        ..sort(
          (left, right) => DateTime.parse(right['date'] as String)
              .compareTo(DateTime.parse(left['date'] as String)),
        );
  final latestSale = recentSales.isEmpty ? null : recentSales.first;
  final recentStockOuts = [...stockOutTransactions]
    ..sort((left, right) => DateTime.parse(right['date'] as String)
        .compareTo(DateTime.parse(left['date'] as String)));

  return {
    'purpose':
        'Use this summary to answer questions about farm performance, best selling periods, crop planting trends, inventory movement, and practical selling suggestions.',
    'salesOverview': {
      'summary': !salesSummaryAvailable
          ? 'Sales data unavailable${salesSummaryError == null ? '.' : ': $salesSummaryError'}'
          : realSalesCount == 0
              ? 'No completed sales transactions are available.'
              : 'There are $realSalesCount completed sales in the loaded records. Confirmed sales total ${_formatPeso(totalSalesAmount)} year to date. Stock issues are inventory movements, not sales.',
      'salesToday': salesSummaryAvailable ? salesSummary.salesToday : null,
      'salesThisMonth': salesSummaryAvailable ? salesSummary.salesThisMonth : null,
      'unitsSoldThisMonth': salesSummaryAvailable ? salesSummary.unitsSoldThisMonth : null,
      'salesTransactionsThisMonth': salesSummaryAvailable ? salesSummary.salesTransactions : null,
      'totalSalesAmountYearToDate': salesSummaryAvailable ? totalSalesAmount : null,
      'realSalesTransactionCount': realSalesCount,
      'inventoryIssueCount': stockOutCount,
      'recentInventoryIssues': recentStockOuts.take(5).toList(),
      'activeSoldItemTypes': soldByItem.length,
      'latestSale': latestSale,
      'recentSales': recentSales.take(5).toList(),
    },
    'itemLineAmountsByMonthBeforeReceiptDiscounts': salesByMonth.take(12).toList(),
    'plantingByMonth': plantingByMonth.take(12).toList(),
    'topSoldItems': topSoldItems.take(8).toList(),
    'topSalesValueItems': topSalesValueItems.take(8).toList(),
    'topPlantedCrops': topPlantedCrops.take(8).toList(),
    'latestCompletedSale': latestSale,
    'bestObservedItemLineMonthBeforeReceiptDiscounts': bestSalesMonth,
    'recommendationHints': [
      if (salesSummaryAvailable && bestSalesMonth != null)
        'Recorded item-line totals before receipt discounts were highest in ${bestSalesMonth['label']}.',
      if (topSoldItems.isNotEmpty)
        '${topSoldItems.first['label']} is currently the top sold item in available inventory movement data.',
      if (salesSummaryAvailable && topSalesValueItems.isNotEmpty)
        '${topSalesValueItems.first['label']} has the highest recorded item-line total before receipt discounts at ${_formatPeso(topSalesValueItems.first['value'] as double)}.',
      if (salesByMonth.length < 3)
        'Monthly item-line figures do not account for receipt-level discounts.',
    ],
  };
}

String _formatPeso(double value) {
  return 'PHP ${value.toStringAsFixed(2)}';
}

List<Map<String, dynamic>> _sortedDoubleEntries(Map<String, double> values) {
  return [
    for (final entry in values.entries)
      {'label': entry.key, 'value': entry.value},
  ]..sort(
      (left, right) => (right['value'] as double).compareTo(
        left['value'] as double,
      ),
    );
}

List<Map<String, dynamic>> _sortedIntEntries(Map<String, int> values) {
  return [
    for (final entry in values.entries)
      {'label': entry.key, 'value': entry.value},
  ]..sort(
      (left, right) => (right['value'] as int).compareTo(
        left['value'] as int,
      ),
    );
}

String _monthKey(DateTime date) {
  final manilaDate = date.toUtc().add(BusinessCalendar.timeZoneOffset);
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${months[manilaDate.month - 1]} ${manilaDate.year}';
}
