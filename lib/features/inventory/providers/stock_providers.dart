import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/stock_inventory_controller.dart';
import '../controllers/stock_inventory_state.dart';
import '../data/repositories/stock_repository.dart';
import '../data/models/stock_model.dart';

final stockInventoryControllerProvider =
    StateNotifierProvider<StockInventoryController, StockInventoryState>((ref) {
  return StockInventoryController(ref.watch(stockRepositoryProvider));
});

final stockSalesTrendProvider = FutureProvider<List<StockSalesTrendRecord>>(
  (ref) => ref.watch(stockRepositoryProvider).getSalesTrendRecords(),
);
