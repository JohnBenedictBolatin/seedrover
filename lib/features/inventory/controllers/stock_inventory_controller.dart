import '../../../shared/models/action_outcome.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/app_input_formatters.dart';
import '../../../core/utils/business_calendar.dart';
import '../data/models/stock_model.dart';
import '../data/models/uncertain_inventory_write.dart';
import '../data/repositories/stock_repository.dart';
import 'stock_inventory_state.dart';

class StockInventoryController extends StateNotifier<StockInventoryState> {
  StockInventoryController(this._repository)
      : super(StockInventoryState.initial()) {
    loadStocks();
    _subscription = _repository.watchStocks().listen(
      (stocks) => _setStocks(
        stocks,
        successMessage: null,
        isLoading: state.isLoading,
      ),
      onError: (_) {
        state = state.copyWith(
          isLoading: state.stocks.isEmpty ? state.isLoading : false,
          errorMessage: state.stocks.isEmpty
              ? 'Inventory records are temporarily unavailable.'
              : state.errorMessage,
        );
      },
    );
  }

  final StockRepository _repository;
  StreamSubscription<List<StockModel>>? _subscription;
  int _loadGeneration = 0;
  int _salesSummaryGeneration = 0;
  List<StockModel> get currentStocks => state.stocks;

  Future<List<ExistingSaleCustomer>> getExistingSaleCustomers() =>
      _repository.getExistingSaleCustomers();

  String? _uncertainWritesKey() {
    final account = _repository.currentAccountId;
    return account == null ? null : 'uncertain_inventory_writes_v1:$account';
  }

  Future<Map<String, UncertainInventoryWrite>> uncertainWrites() async {
    final key = _uncertainWritesKey();
    if (key == null) return {};
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(key) ?? const [];
    final pending = <String, UncertainInventoryWrite>{};
    for (final entry in entries) {
      try {
        final json = jsonDecode(entry) as Map<String, dynamic>;
        final write = UncertainInventoryWrite(
          stockId: json['stockId'] as String,
          action: json['action'] as String,
          attempted: json['attempted'] as String,
          createdAt: DateTime.parse(json['createdAt'] as String),
          reference: json['reference'] as String?,
        );
        pending[write.stockId] = write;
      } catch (_) {
        // Ignore a damaged entry without deleting other account-scoped work.
      }
    }
    return pending;
  }

  Future<void> markUncertainWrite(UncertainInventoryWrite write) async {
    final key = _uncertainWritesKey();
    if (key == null) return;
    final writes = await uncertainWrites();
    writes[write.stockId] = write;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        key,
        writes.values
            .map((entry) => jsonEncode({
                  'stockId': entry.stockId,
                  'action': entry.action,
                  'attempted': entry.attempted,
                  'createdAt': entry.createdAt.toIso8601String(),
                  'reference': entry.reference,
                }))
            .toList());
  }

  Future<void> resolveUncertainWrite(String stockId) async {
    final key = _uncertainWritesKey();
    if (key == null) return;
    final writes = await uncertainWrites()
      ..remove(stockId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        key,
        writes.values
            .map((entry) => jsonEncode({
                  'stockId': entry.stockId,
                  'action': entry.action,
                  'attempted': entry.attempted,
                  'createdAt': entry.createdAt.toIso8601String(),
                  'reference': entry.reference,
                }))
            .toList());
  }

  Future<ActionOutcome?> pendingWriteFor(String stockId) async =>
      (await uncertainWrites())[stockId] == null
          ? null
          : const ActionOutcome.unknown(
              'A previous inventory write has not been reconciled. Check its record before submitting another change.',
            );

  Future<void> _rememberUncertain(
      Object error, String stockId, String action, String attempted,
      {String? reference}) async {
    if (error is! UnconfirmedWrite) return;
    await markUncertainWrite(UncertainInventoryWrite(
      stockId: error.stockId ?? stockId,
      action: action,
      attempted: attempted,
      createdAt: DateTime.now(),
      reference: reference,
    ));
  }

  Future<void> loadStocks() async {
    final generation = ++_loadGeneration;
    state = state.copyWith(isLoading: true, errorMessage: null);
    late final List<StockModel> stocks;
    try {
      stocks = await _repository.getStocks();
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      state = state.copyWith(
        isLoading: false,
        isSalesSummaryLoading: false,
        salesSummaryError:
            'Sales totals are unavailable until inventory loads.',
        errorMessage: _friendlyError(
          error,
          fallback: 'Unable to load inventory data.',
        ),
      );
      return;
    }
    if (!mounted || generation != _loadGeneration) return;

    _setStocks(stocks, successMessage: null, isLoading: true);
    await refreshSalesSummary();
    if (mounted && generation == _loadGeneration) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refreshSalesSummary() async {
    final generation = ++_salesSummaryGeneration;
    state = state.copyWith(isSalesSummaryLoading: true);
    try {
      final salesSummary = await _repository.getSalesSummary();
      if (!mounted || generation != _salesSummaryGeneration) return;
      state = state.copyWith(
        salesSummary: salesSummary,
        salesSummaryError: null,
        isSalesSummaryLoading: false,
        hasSalesSummary: true,
      );
    } catch (_) {
      if (!mounted || generation != _salesSummaryGeneration) return;
      state = state.copyWith(
        salesSummaryError: 'Sales totals could not be refreshed.',
        isSalesSummaryLoading: false,
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

  Future<StockModel> refreshStockForReview(String id) async {
    final stocks = await _repository.getStocks();
    _setStocks(stocks, successMessage: null, isLoading: false);
    return stocks.firstWhere((stock) => stock.id == id);
  }

  Future<String?> createStock(
    StockModel stock, {
    StockImageUpload? imageUpload,
  }) async {
    final normalizedName = stock.name.trim().toLowerCase();
    if (normalizedName.isEmpty) {
      return 'Item name is required.';
    }

    if (state.stocks.any(
      (existing) => existing.name.trim().toLowerCase() == normalizedName,
    )) {
      return 'Item already exists.';
    }

    try {
      final createdStock = await _repository.createStock(
        stock,
        imageUpload: imageUpload,
      );
      _setStocks(
        [createdStock, ...state.stocks],
        successMessage: 'Inventory item created.',
        isLoading: false,
        resetFilters: true,
      );
      return null;
    } catch (error) {
      if (error is UnconfirmedWrite && error.stockId != null) {
        await _rememberUncertain(
            error, error.stockId!, 'Create item', stock.name);
      }
      final message = _mutationError(error, 'Unable to create stock item.');
      state = state.copyWith(errorMessage: message);
      return message;
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
    String? requestId,
  }) async {
    final pending = await pendingWriteFor(stockId);
    if (pending != null) return pending.message;
    if (quantity <= 0) {
      return 'Quantity must be greater than zero.';
    }

    final stock = stockById(stockId);

    if (stock == null) {
      return 'Inventory item was not found.';
    }

    try {
      final updatedStock = await _repository.stockIn(
        stock: stock,
        quantity: quantity,
        supplier: supplier,
        remarks: remarks,
        requestId: requestId,
      );
      _replaceStock(
        updatedStock,
        successMessage: 'Harvest stock added successfully.',
      );
    } catch (error) {
      await _rememberUncertain(error, stockId, 'Receive stock', '$quantity');
      return _mutationError(error, 'Unable to add stock.');
    }

    return null;
  }

  Future<String?> stockOut({
    required String stockId,
    required double quantity,
    required String purpose,
    required String remarks,
    required String performedBy,
    String? requestId,
    String? batchId,
  }) async {
    final pending = await pendingWriteFor(stockId);
    if (pending != null) return pending.message;
    if (quantity <= 0) {
      return 'Quantity must be greater than zero.';
    }

    final stock = stockById(stockId);

    if (stock == null) {
      return 'Inventory item was not found.';
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
        requestId: requestId,
        batchId: batchId,
      );
      _replaceStock(updatedStock,
          successMessage: 'Stock deducted successfully.');
    } catch (error) {
      await _rememberUncertain(error, stockId, 'Issue stock', '$quantity');
      return _mutationError(error, 'Unable to deduct stock.');
    }

    return null;
  }

  Future<String?> adjustStock({
    required String stockId,
    required double newQuantity,
    required String reason,
    required String remarks,
    required String performedBy,
    String? requestId,
  }) async {
    final pending = await pendingWriteFor(stockId);
    if (pending != null) return pending.message;
    if (newQuantity < 0) {
      return 'New quantity cannot be negative.';
    }

    final stock = stockById(stockId);

    if (stock == null) {
      return 'Inventory item was not found.';
    }

    try {
      final updatedStock = await _repository.adjustStock(
        stock: stock,
        newQuantity: newQuantity,
        reason: reason,
        remarks: remarks,
        requestId: requestId,
      );
      _replaceStock(updatedStock,
          successMessage: 'Stock adjusted successfully.');
    } catch (error) {
      await _rememberUncertain(
          error, stockId, 'Adjust quantity', '$newQuantity');
      return _mutationError(error, 'Unable to adjust stock.');
    }

    return null;
  }

  Future<String?> recordSale(RecordSaleRequest request) async {
    final pending = await pendingWriteFor(request.stock.id);
    if (pending != null) return pending.message;
    if (state.isSavingSale) {
      return 'Sale is already being saved.';
    }

    final contactError = AppInputFormatters.validateContactNumber(
      request.customerContact,
      required: true,
    );
    if (contactError != null) return contactError;

    if (request.quantitySold <= 0) {
      return 'Quantity sold must be greater than zero.';
    }

    if (request.quantitySold > request.stock.currentQuantity) {
      return 'Quantity sold cannot exceed current stock.';
    }

    if (request.unitPrice < 0) {
      return 'Unit price cannot be negative.';
    }

    if (request.paymentMethod == 'Other' &&
        (request.otherPaymentMethod == null ||
            request.otherPaymentMethod!.trim().isEmpty)) {
      return 'Enter the other payment method used.';
    }

    if (request.paymentMethod != 'Cash' &&
        (request.transactionReference == null ||
            request.transactionReference!.trim().isEmpty)) {
      return 'Transaction ID is required for non-cash sales.';
    }

    try {
      state = state.copyWith(isSavingSale: true);
      final updatedStock = await _repository.recordSale(request);
      StockSalesSummaryModel? salesSummary;
      String? salesSummaryError;
      try {
        salesSummary = await _repository.getSalesSummary();
      } catch (_) {
        salesSummary = _summaryIncludingSale(state.salesSummary, request);
        salesSummaryError =
            'Sale saved, but dashboard totals could not be refreshed.';
      }
      _replaceStock(
        updatedStock,
        successMessage: 'Sale recorded successfully.',
        salesSummary: salesSummary,
      );
      state = state.copyWith(salesSummaryError: salesSummaryError);
    } catch (error) {
      await _rememberUncertain(error, request.stock.id, 'Record sale',
          '${request.quantitySold} ${request.stock.unit} at ${request.unitPrice}',
          reference: request.transactionReference);
      state = state.copyWith(isSavingSale: false);
      return _mutationError(error, 'Unable to record sale.');
    }

    state = state.copyWith(isSavingSale: false);
    return null;
  }

  Future<String?> updateStock(StockModel stock) async {
    final pending = await pendingWriteFor(stock.id);
    if (pending != null) return pending.message;
    final normalizedName = stock.name.trim().toLowerCase();
    if (state.stocks.any((existing) =>
        existing.id != stock.id &&
        existing.name.trim().toLowerCase() == normalizedName)) {
      return 'Item already exists.';
    }
    try {
      final updatedStock = await _repository.updateStock(stock);
      StockSalesSummaryModel? salesSummary;
      try {
        salesSummary = await _repository.getSalesSummary();
      } catch (_) {
        // The item update succeeded; a summary refresh failure must not
        // misreport that inventory edit as failed.
      }
      _replaceStock(
        updatedStock,
        successMessage: 'Inventory item updated.',
        salesSummary: salesSummary,
      );
    } catch (error) {
      await _rememberUncertain(error, stock.id, 'Edit item', stock.name);
      final message = _mutationError(error, 'Unable to update stock item.');
      state = state.copyWith(errorMessage: message);
      return message;
    }
    return null;
  }

  Future<bool> deleteStock(String stockId) async {
    if (await pendingWriteFor(stockId) != null) return false;
    try {
      await _repository.deleteStock(stockId);
      final stocks =
          state.stocks.where((stock) => stock.id != stockId).toList();
      _setStocks(stocks,
          successMessage: 'Inventory item deleted.', isLoading: false);
      return true;
    } catch (error) {
      await _rememberUncertain(error, stockId, 'Delete item', '');
      state = state.copyWith(
        errorMessage: _mutationError(error, 'Unable to delete stock item.'),
      );
      return false;
    }
  }

  void clearSuccessMessage() {
    state = state.copyWith(successMessage: null);
  }

  void clearErrorMessage() {
    state = state.copyWith(errorMessage: null);
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

  void _replaceStock(
    StockModel stock, {
    required String successMessage,
    StockSalesSummaryModel? salesSummary,
  }) {
    final stocks = [
      for (final item in state.stocks)
        if (item.id == stock.id) stock else item,
    ];

    _setStocks(
      stocks,
      successMessage: successMessage,
      isLoading: false,
      salesSummary: salesSummary,
    );
  }

  void _setStocks(
    List<StockModel> stocks, {
    required String? successMessage,
    required bool isLoading,
    StockSalesSummaryModel? salesSummary,
    bool resetFilters = false,
  }) {
    final searchQuery = resetFilters ? '' : state.searchQuery;
    final selectedCategory = resetFilters ? null : state.selectedCategory;
    final selectedFilter =
        resetFilters ? StockFilterType.all : state.selectedFilter;
    final selectedSort =
        resetFilters ? StockSortType.recentlyUpdated : state.selectedSort;
    final filteredStocks = _applyFilters(
      stocks: stocks,
      searchQuery: searchQuery,
      selectedCategory: selectedCategory,
      selectedFilter: selectedFilter,
      selectedSort: selectedSort,
    );

    state = state.copyWith(
      stocks: stocks,
      filteredStocks: filteredStocks,
      searchQuery: searchQuery,
      selectedCategory: selectedCategory,
      selectedFilter: selectedFilter,
      selectedSort: selectedSort,
      successMessage: successMessage,
      errorMessage: null,
      isLoading: isLoading,
      isSavingSale: false,
      salesSummary: salesSummary ?? state.salesSummary,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

StockSalesSummaryModel _summaryIncludingSale(
  StockSalesSummaryModel current,
  RecordSaleRequest request,
) {
  final now = BusinessCalendar.now();
  final saleDate = request.saleDate.toUtc();
  final today = BusinessCalendar.startOfDay(now);
  final weekStart = BusinessCalendar.startOfWeek(now);
  final monthStart = BusinessCalendar.startOfMonth(now);
  final nextYear = BusinessCalendar.startOfNextYear(now);
  final nextMonth = BusinessCalendar.startOfNextMonth(now);
  final tomorrow = today.add(const Duration(days: 1));
  final occurredToday = !saleDate.isBefore(today) &&
      saleDate.isBefore(tomorrow) &&
      !saleDate.isAfter(now);
  final occurredThisWeek = !saleDate.isBefore(weekStart) &&
      saleDate.isBefore(tomorrow) &&
      !saleDate.isAfter(now);
  final occurredThisMonth = !saleDate.isBefore(monthStart) &&
      saleDate.isBefore(nextMonth) &&
      !saleDate.isAfter(now);
  final occurredThisYear =
      !saleDate.isBefore(BusinessCalendar.startOfYear(now)) &&
          saleDate.isBefore(nextYear) &&
          !saleDate.isAfter(now);

  return StockSalesSummaryModel(
    salesToday: current.salesToday + (occurredToday ? request.totalAmount : 0),
    salesThisWeek:
        current.salesThisWeek + (occurredThisWeek ? request.totalAmount : 0),
    salesThisMonth:
        current.salesThisMonth + (occurredThisMonth ? request.totalAmount : 0),
    salesThisYear:
        current.salesThisYear + (occurredThisYear ? request.totalAmount : 0),
    unitsSoldThisMonth: current.unitsSoldThisMonth +
        (occurredThisMonth ? request.quantitySold : 0),
    salesTransactions: current.salesTransactions + (occurredThisMonth ? 1 : 0),
    salesTransactionsToday:
        current.salesTransactionsToday + (occurredToday ? 1 : 0),
    salesTransactionsThisWeek:
        current.salesTransactionsThisWeek + (occurredThisWeek ? 1 : 0),
    salesTransactionsThisYear:
        current.salesTransactionsThisYear + (occurredThisYear ? 1 : 0),
  );
}

const _noCategoryChange = Object();

String _friendlyError(Object error, {required String fallback}) {
  if (error is PostgrestException) {
    final message = error.message;

    if (message.contains('schema cache') ||
        message.contains('record_inventory_sale') ||
        message.contains('Could not find the function')) {
      return 'Inventory database is not fully upgraded yet. Apply the latest Supabase migration and try again.';
    }

    if (message.toLowerCase().contains('permission') ||
        message.toLowerCase().contains('not allowed')) {
      return 'You do not have permission to perform this inventory action.';
    }

    final lowerMessage = message.toLowerCase();
    final diagnostics =
        '$lowerMessage ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    if (diagnostics.contains('inventory item with this name already exists') ||
        diagnostics.contains('item already exists') ||
        diagnostics.contains('inventory_item_name_normalized_idx') ||
        (error.code == '23505' &&
            diagnostics.contains('item_name') &&
            diagnostics.contains('inventory'))) {
      return 'Item already exists.';
    }

    if (message.trim().isNotEmpty) {
      return message;
    }
  }

  return fallback;
}

String _mutationError(Object error, String fallback) {
  if (error is UnconfirmedWrite) {
    return 'Outcome not confirmed: ${error.message}';
  }
  if (error is ArgumentError) {
    return fallback;
  }
  if (error is PostgrestException) {
    return _friendlyError(error, fallback: fallback);
  }
  return 'Outcome not confirmed: Check the latest transactions before starting another operation. Your input is still here.';
}
