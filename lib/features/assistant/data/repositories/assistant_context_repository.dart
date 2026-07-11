import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../crops/data/models/crop_model.dart';
import '../../../crops/providers/crop_providers.dart';
import '../../../dashboard/providers/dashboard_providers.dart';
import '../../../inventory/data/models/stock_model.dart';
import '../../../inventory/providers/stock_providers.dart';
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
            'batteryLevel': rover.batteryLevel,
            'seedLevel': rover.seedLevel,
            'wifiConnected': rover.wifiConnected,
            'bluetoothConnected': rover.bluetoothConnected,
            'cameraConnected': rover.cameraConnected,
            'isInUse': rover.isInUse,
            'usageMinutes': rover.usageDuration.inMinutes,
            'lastCommunication': rover.lastCommunication.toIso8601String(),
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
          'timestamp': activity.timestamp.toIso8601String(),
        },
    ],
    farmAnalytics: _farmAnalyticsContext(
      crops: cropState.crops,
      stocks: stockState.stocks,
    ),
  );
});

Map<String, dynamic> _cropContext(CropModel crop) {
  final latestMaintenance = [...crop.maintenanceHistory]
    ..sort((left, right) => right.performedAt.compareTo(left.performedAt));
  final latestWatering = crop.maintenanceHistory
      .where((record) => record.activity == CropMaintenanceActivity.watered)
      .toList()
    ..sort((left, right) => right.performedAt.compareTo(left.performedAt));

  return {
    'id': crop.id,
    'name': crop.name,
    'variety': crop.variety,
    'location': crop.location,
    'quantity': crop.safeSeedCount,
    'plantingDate': crop.plantingDate.toIso8601String(),
    'estimatedHarvest': crop.estimatedHarvest.toIso8601String(),
    'growthStage': crop.growthStage.label,
    'status': crop.status.label,
    'manager': crop.managerName,
    'progress': crop.progress,
    'lastWateredAt': crop.lastWateredAt?.toIso8601String() ??
        (latestWatering.isEmpty
            ? null
            : latestWatering.first.performedAt.toIso8601String()),
    'latestMaintenance': latestMaintenance.isEmpty
        ? null
        : {
            'activity': latestMaintenance.first.activity.label,
            'performedAt': latestMaintenance.first.performedAt.toIso8601String(),
            'performedBy': latestMaintenance.first.performedBy,
            'notes': latestMaintenance.first.notes,
          },
    'maintenanceNotes': crop.maintenanceNotes.take(3).toList(),
    'reminders': crop.reminders.take(3).toList(),
  };
}

Map<String, dynamic> _stockContext(StockModel stock) {
  final latestTransactions = [...stock.transactions]
    ..sort((left, right) => right.performedAt.compareTo(left.performedAt));
  final latestStockIn = stock.transactions
      .where((transaction) => transaction.type == StockTransactionType.stockIn)
      .toList()
    ..sort((left, right) => right.performedAt.compareTo(left.performedAt));

  return {
    'id': stock.id,
    'name': stock.name,
    'category': stock.category.label,
    'quantity': stock.currentQuantity,
    'unit': stock.unit,
    'status': stock.status.label,
    'storageLocation': stock.storageLocation,
    'minimumStockLevel': stock.minimumStockLevel,
    'supplier': stock.supplier,
    'dateAdded': stock.dateAdded.toIso8601String(),
    'lastUpdated': stock.lastUpdated.toIso8601String(),
    'lastRestockedAt': latestStockIn.isEmpty
        ? null
        : latestStockIn.first.performedAt.toIso8601String(),
    'latestTransaction': latestTransactions.isEmpty
        ? null
        : {
            'type': latestTransactions.first.type.label,
            'quantity': latestTransactions.first.quantity,
            'performedAt': latestTransactions.first.performedAt.toIso8601String(),
            'performedBy': latestTransactions.first.performedBy,
            'remarks': latestTransactions.first.remarks,
          },
    'notes': stock.notes,
  };
}

Map<String, dynamic> _farmAnalyticsContext({
  required List<CropModel> crops,
  required List<StockModel> stocks,
}) {
  final monthlySales = <String, double>{};
  final monthlyPlanting = <String, int>{};
  final soldByItem = <String, double>{};
  final plantedByCrop = <String, int>{};
  final stockOutTransactions = <Map<String, dynamic>>[];
  var totalSoldQuantity = 0.0;
  var stockOutCount = 0;

  for (final crop in crops) {
    final monthKey = _monthKey(crop.plantingDate);
    monthlyPlanting.update(monthKey, (value) => value + 1, ifAbsent: () => 1);
    plantedByCrop.update(crop.name, (value) => value + 1, ifAbsent: () => 1);
  }

  for (final stock in stocks) {
    for (final transaction in stock.transactions) {
      if (transaction.type != StockTransactionType.stockOut) {
        continue;
      }

      final monthKey = _monthKey(transaction.performedAt);
      totalSoldQuantity += transaction.quantity;
      stockOutCount += 1;
      monthlySales.update(
        monthKey,
        (value) => value + transaction.quantity,
        ifAbsent: () => transaction.quantity,
      );
      soldByItem.update(
        stock.name,
        (value) => value + transaction.quantity,
        ifAbsent: () => transaction.quantity,
      );
      stockOutTransactions.add({
        'item': stock.name,
        'quantity': transaction.quantity,
        'unit': stock.unit,
        'date': transaction.performedAt.toIso8601String(),
        'remarks': transaction.remarks,
      });
    }
  }

  final salesByMonth = _sortedDoubleEntries(monthlySales);
  final plantingByMonth = _sortedIntEntries(monthlyPlanting);
  final topSoldItems = _sortedDoubleEntries(soldByItem);
  final topPlantedCrops = _sortedIntEntries(plantedByCrop);
  final bestSalesMonth = salesByMonth.isEmpty ? null : salesByMonth.first;
  final recentSales = [...stockOutTransactions]
    ..sort(
      (left, right) => DateTime.parse(right['date'] as String)
          .compareTo(DateTime.parse(left['date'] as String)),
    );
  final latestSale = recentSales.isEmpty ? null : recentSales.first;

  return {
    'purpose':
        'Use this summary to answer questions about farm performance, best selling periods, crop planting trends, inventory movement, and practical selling suggestions.',
    'currentSalesStatus': {
      'summary': stockOutCount == 0
          ? 'No stock-out or sales transactions are available in the current app data.'
          : 'Current app data has $stockOutCount stock-out/sales transaction(s), totaling ${_formatQuantity(totalSoldQuantity)} units across ${soldByItem.length} item type(s).',
      'totalSoldQuantity': totalSoldQuantity,
      'stockOutTransactionCount': stockOutCount,
      'activeSoldItemTypes': soldByItem.length,
      'latestSale': latestSale,
      'recentSales': recentSales.take(5).toList(),
    },
    'salesByMonth': salesByMonth.take(12).toList(),
    'plantingByMonth': plantingByMonth.take(12).toList(),
    'topSoldItems': topSoldItems.take(8).toList(),
    'topPlantedCrops': topPlantedCrops.take(8).toList(),
    'latestStockOut': latestSale,
    'bestObservedSalesMonth': bestSalesMonth,
    'recommendationHints': [
      if (bestSalesMonth != null)
        'Existing stock-out data is strongest in ${bestSalesMonth['label']}; consider preparing harvest and market distribution before or during this period.',
      if (topSoldItems.isNotEmpty)
        '${topSoldItems.first['label']} is currently the top sold item in available inventory movement data.',
      if (salesByMonth.length < 3)
        'Sales seasonality confidence is low because fewer than three months of stock-out data are available.',
    ],
  };
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }

  return value.toStringAsFixed(1);
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

  return '${months[date.month - 1]} ${date.year}';
}
