import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/stock_inventory_controller.dart';
import '../controllers/stock_inventory_state.dart';
import '../data/repositories/stock_repository.dart';

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return const StockRepository();
});

final stockInventoryControllerProvider =
    StateNotifierProvider<StockInventoryController, StockInventoryState>((ref) {
  return StockInventoryController(ref.watch(stockRepositoryProvider));
});
