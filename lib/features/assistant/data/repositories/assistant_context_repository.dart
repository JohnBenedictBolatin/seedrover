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
  final dashboard = ref.watch(dashboardProvider);

  return AssistantContextModel(
    generatedAt: DateTime.now(),
    rover: {
      'unitName': dashboard.rover.unitName,
      'status': dashboard.rover.status,
      'plantingStatus': dashboard.rover.plantingStatus,
      'batteryLevel': dashboard.rover.batteryLevel,
      'seedLevel': dashboard.rover.seedLevel,
      'wifiConnected': dashboard.rover.wifiConnected,
      'bluetoothConnected': dashboard.rover.bluetoothConnected,
      'cameraConnected': dashboard.rover.cameraConnected,
      'isInUse': dashboard.rover.isInUse,
      'usageMinutes': dashboard.rover.usageDuration.inMinutes,
      'lastCommunication': dashboard.rover.lastCommunication.toIso8601String(),
    },
    crops: [
      for (final crop in cropState.crops.take(12)) _cropContext(crop),
    ],
    stocks: [
      for (final stock in stockState.stocks.take(12)) _stockContext(stock),
    ],
    recentActivities: [
      for (final activity in dashboard.recentActivities.take(8))
        {
          'title': activity.title,
          'description': activity.description,
          'module': activity.module,
          'timestamp': activity.timestamp.toIso8601String(),
        },
    ],
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

