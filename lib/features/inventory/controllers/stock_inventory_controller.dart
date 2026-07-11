import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/stock_model.dart';
import '../data/repositories/stock_repository.dart';
import 'stock_inventory_state.dart';

class StockInventoryController extends StateNotifier<StockInventoryState> {
  StockInventoryController(this._repository)
      : super(StockInventoryState.initial()) {
    loadStocks();
    _subscription = _repository.watchStocks().listen(
      (stocks) => _setStocks(stocks, successMessage: null, isLoading: false),
      onError: (_) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: null,
        );
      },
    );
  }

  final StockRepository _repository;
  StreamSubscription<List<StockModel>>? _subscription;

  Future<void> loadStocks() async {
    try {
      final stocks = await _repository.getStocks();
      _setStocks(stocks, successMessage: null, isLoading: false);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load inventory data.',
      );
    }
  }

  Future<void> refreshStocks() async {
    state = state.copyWith(isLoading: true, successMessage: null);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await loadStocks();
  }

  StockModel? stockById(String stockId) {
    for (final stock in state.stocks) {
      if (stock.id == stockId) {
        return stock;
      }
    }

    return null;
  }

  Future<void> createStock(
    StockModel stock, {
    StockImageUpload? imageUpload,
  }) async {
    try {
      final createdStock = await _repository.createStock(
        stock,
        imageUpload: imageUpload,
      );
      _setStocks(
        [createdStock, ...state.stocks],
        successMessage: 'Stock item created.',
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(errorMessage: 'Unable to create stock item.');
    }
  }

  void updateSearch(String query) {
    _updateFilters(searchQuery: query);
  }

  void updateCategory(StockCategory? category) {
    _updateFilters(selectedCategory: category);
  }

  void updateFilter(StockFilterType filter) {
    _updateFilters(selectedFilter: filter);
  }

  void updateSort(StockSortType sort) {
    _updateFilters(selectedSort: sort);
  }

  void clearFilters() {
    final filteredStocks = _applyFilters(
      stocks: state.stocks,
      searchQuery: '',
      selectedCategory: null,
      selectedFilter: StockFilterType.all,
      selectedSort: StockSortType.recentlyUpdated,
    );

    state = state.copyWith(
      searchQuery: '',
      selectedCategory: null,
      selectedFilter: StockFilterType.all,
      selectedSort: StockSortType.recentlyUpdated,
      filteredStocks: filteredStocks,
      successMessage: null,
    );
  }

  Future<String?> stockIn({
    required String stockId,
    required double quantity,
    required String supplier,
    required String remarks,
    required String performedBy,
  }) async {
    if (quantity <= 0) {
      return 'Quantity must be greater than zero.';
    }

    final stock = stockById(stockId);

    if (stock == null) {
      return 'Stock item was not found.';
    }

    try {
      final updatedStock = await _repository.stockIn(
        stock: stock,
        quantity: quantity,
        supplier: supplier,
        remarks: remarks,
      );
      _replaceStock(
        updatedStock,
        successMessage: 'Harvest stock added successfully.',
      );
    } catch (_) {
      return 'Unable to add stock.';
    }

    return null;
  }

  Future<String?> stockOut({
    required String stockId,
    required double quantity,
    required String purpose,
    required String remarks,
    required String performedBy,
  }) async {
    if (quantity <= 0) {
      return 'Quantity must be greater than zero.';
    }

    final stock = stockById(stockId);

    if (stock == null) {
      return 'Stock item was not found.';
    }

    if (quantity > stock.currentQuantity) {
      return 'Quantity cannot exceed current stock.';
    }

    try {
      final updatedStock = await _repository.stockOut(
        stock: stock,
        quantity: quantity,
        purpose: purpose,
        remarks: remarks,
      );
      _replaceStock(updatedStock, successMessage: 'Stock deducted successfully.');
    } catch (_) {
      return 'Unable to deduct stock.';
    }

    return null;
  }

  Future<String?> adjustStock({
    required String stockId,
    required double newQuantity,
    required String reason,
    required String remarks,
    required String performedBy,
  }) async {
    if (newQuantity < 0) {
      return 'New quantity cannot be negative.';
    }

    final stock = stockById(stockId);

    if (stock == null) {
      return 'Stock item was not found.';
    }

    try {
      final updatedStock = await _repository.adjustStock(
        stock: stock,
        newQuantity: newQuantity,
        reason: reason,
        remarks: remarks,
      );
      _replaceStock(updatedStock, successMessage: 'Stock adjusted successfully.');
    } catch (_) {
      return 'Unable to adjust stock.';
    }

    return null;
  }

  Future<void> updateStock(StockModel stock) async {
    try {
      final updatedStock = await _repository.updateStock(stock);
      _replaceStock(updatedStock, successMessage: 'Stock item updated.');
    } catch (_) {
      state = state.copyWith(errorMessage: 'Unable to update stock item.');
    }
  }

  Future<void> deleteStock(String stockId) async {
    try {
      await _repository.deleteStock(stockId);
      final stocks = state.stocks.where((stock) => stock.id != stockId).toList();
      _setStocks(stocks, successMessage: 'Stock item deleted.', isLoading: false);
    } catch (_) {
      state = state.copyWith(errorMessage: 'Unable to delete stock item.');
    }
  }

  void clearSuccessMessage() {
    state = state.copyWith(successMessage: null);
  }

  void _updateFilters({
    String? searchQuery,
    Object? selectedCategory = _noCategoryChange,
    StockFilterType? selectedFilter,
    StockSortType? selectedSort,
  }) {
    final nextSearchQuery = searchQuery ?? state.searchQuery;
    final nextCategory = selectedCategory == _noCategoryChange
        ? state.selectedCategory
        : selectedCategory as StockCategory?;
    final nextFilter = selectedFilter ?? state.selectedFilter;
    final nextSort = selectedSort ?? state.selectedSort;
    final filteredStocks = _applyFilters(
      stocks: state.stocks,
      searchQuery: nextSearchQuery,
      selectedCategory: nextCategory,
      selectedFilter: nextFilter,
      selectedSort: nextSort,
    );

    state = state.copyWith(
      searchQuery: nextSearchQuery,
      selectedCategory: nextCategory,
      selectedFilter: nextFilter,
      selectedSort: nextSort,
      filteredStocks: filteredStocks,
      successMessage: null,
    );
  }

  List<StockModel> _applyFilters({
    required List<StockModel> stocks,
    required String searchQuery,
    required StockCategory? selectedCategory,
    required StockFilterType selectedFilter,
    required StockSortType selectedSort,
  }) {
    final normalizedQuery = searchQuery.trim().toLowerCase();
    final filtered = stocks.where((stock) {
      final matchesSearch = normalizedQuery.isEmpty ||
          stock.name.toLowerCase().contains(normalizedQuery) ||
          stock.id.toLowerCase().contains(normalizedQuery) ||
          stock.category.label.toLowerCase().contains(normalizedQuery) ||
          stock.storageLocation.toLowerCase().contains(normalizedQuery);
      final matchesCategory =
          selectedCategory == null || stock.category == selectedCategory;
      final matchesFilter = switch (selectedFilter) {
        StockFilterType.all => true,
        StockFilterType.inStock => stock.status == StockStatus.inStock,
        StockFilterType.lowStock => stock.status == StockStatus.lowStock,
        StockFilterType.criticalStock =>
          stock.status == StockStatus.criticalStock,
        StockFilterType.outOfStock => stock.status == StockStatus.outOfStock,
      };

      return matchesSearch && matchesCategory && matchesFilter;
    }).toList();

    filtered.sort((left, right) {
      return switch (selectedSort) {
        StockSortType.newest => right.dateAdded.compareTo(left.dateAdded),
        StockSortType.oldest => left.dateAdded.compareTo(right.dateAdded),
        StockSortType.name => left.name.compareTo(right.name),
        StockSortType.quantity =>
          left.currentQuantity.compareTo(right.currentQuantity),
        StockSortType.recentlyUpdated =>
          right.lastUpdated.compareTo(left.lastUpdated),
      };
    });

    return filtered;
  }

  void _replaceStock(StockModel stock, {required String successMessage}) {
    final stocks = [
      for (final item in state.stocks)
        if (item.id == stock.id) stock else item,
    ];

    _setStocks(stocks, successMessage: successMessage, isLoading: false);
  }

  void _setStocks(
    List<StockModel> stocks, {
    required String? successMessage,
    required bool isLoading,
  }) {
    final filteredStocks = _applyFilters(
      stocks: stocks,
      searchQuery: state.searchQuery,
      selectedCategory: state.selectedCategory,
      selectedFilter: state.selectedFilter,
      selectedSort: state.selectedSort,
    );

    state = state.copyWith(
      stocks: stocks,
      filteredStocks: filteredStocks,
      successMessage: successMessage,
      errorMessage: null,
      isLoading: isLoading,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

const _noCategoryChange = Object();
