import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/stock_model.dart';
import '../data/repositories/stock_repository.dart';
import 'stock_inventory_state.dart';

class StockInventoryController extends StateNotifier<StockInventoryState> {
  StockInventoryController(this._repository)
      : super(StockInventoryState.initial()) {
    loadStocks();
  }

  final StockRepository _repository;

  void loadStocks() {
    try {
      final stocks = _repository.getStocks();
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
    loadStocks();
  }

  StockModel? stockById(String stockId) {
    for (final stock in state.stocks) {
      if (stock.id == stockId) {
        return stock;
      }
    }

    return null;
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

  String? stockIn({
    required String stockId,
    required double quantity,
    required String supplier,
    required String remarks,
    required String performedBy,
  }) {
    if (quantity <= 0) {
      return 'Quantity must be greater than zero.';
    }

    final stock = stockById(stockId);

    if (stock == null) {
      return 'Stock item was not found.';
    }

    final now = DateTime.now();

    _replaceStock(
      stock.copyWith(
        currentQuantity: stock.currentQuantity + quantity,
        supplier: supplier.trim().isEmpty ? stock.supplier : supplier.trim(),
        lastUpdated: now,
        transactions: [
          StockTransactionModel(
            type: StockTransactionType.stockIn,
            quantity: quantity,
            performedAt: now,
            remarks: _cleanRemarks(remarks, fallback: 'Harvest stock added.'),
            performedBy: performedBy,
          ),
          ...stock.transactions,
        ],
      ),
      successMessage: 'Harvest stock added successfully.',
    );

    return null;
  }

  String? stockOut({
    required String stockId,
    required double quantity,
    required String purpose,
    required String remarks,
    required String performedBy,
  }) {
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

    final now = DateTime.now();
    final purposeText = purpose.trim().isEmpty ? 'Stock used.' : purpose.trim();
    final remarksText = remarks.trim().isEmpty ? purposeText : remarks.trim();

    _replaceStock(
      stock.copyWith(
        currentQuantity: stock.currentQuantity - quantity,
        lastUpdated: now,
        transactions: [
          StockTransactionModel(
            type: StockTransactionType.stockOut,
            quantity: quantity,
            performedAt: now,
            remarks: '$purposeText - $remarksText',
            performedBy: performedBy,
          ),
          ...stock.transactions,
        ],
      ),
      successMessage: 'Stock deducted successfully.',
    );

    return null;
  }

  String? adjustStock({
    required String stockId,
    required double newQuantity,
    required String reason,
    required String remarks,
    required String performedBy,
  }) {
    if (newQuantity < 0) {
      return 'New quantity cannot be negative.';
    }

    final stock = stockById(stockId);

    if (stock == null) {
      return 'Stock item was not found.';
    }

    final now = DateTime.now();
    final reasonText = reason.trim().isEmpty ? 'Stock adjusted.' : reason.trim();
    final remarksText = remarks.trim().isEmpty ? reasonText : remarks.trim();

    _replaceStock(
      stock.copyWith(
        currentQuantity: newQuantity,
        lastUpdated: now,
        transactions: [
          StockTransactionModel(
            type: StockTransactionType.adjustment,
            quantity: newQuantity,
            performedAt: now,
            remarks: '$reasonText - $remarksText',
            performedBy: performedBy,
          ),
          ...stock.transactions,
        ],
      ),
      successMessage: 'Stock adjusted successfully.',
    );

    return null;
  }

  void updateStock(StockModel stock) {
    _replaceStock(
      stock.copyWith(lastUpdated: DateTime.now()),
      successMessage: 'Stock item updated.',
    );
  }

  void deleteStock(String stockId) {
    final stocks = state.stocks.where((stock) => stock.id != stockId).toList();
    _setStocks(stocks, successMessage: 'Stock item deleted.', isLoading: false);
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

  String _cleanRemarks(String value, {required String fallback}) {
    return value.trim().isEmpty ? fallback : value.trim();
  }
}

const _noCategoryChange = Object();
