import '../data/models/stock_model.dart';

enum StockFilterType {
  all,
  inStock,
  lowStock,
  criticalStock,
  outOfStock;

  String get label {
    return switch (this) {
      StockFilterType.all => 'All',
      StockFilterType.inStock => 'In Stock',
      StockFilterType.lowStock => 'Low Stock',
      StockFilterType.criticalStock => 'Critical',
      StockFilterType.outOfStock => 'Out',
    };
  }
}

enum StockSortType {
  newest,
  oldest,
  name,
  quantity,
  recentlyUpdated;

  String get label {
    return switch (this) {
      StockSortType.newest => 'Newest',
      StockSortType.oldest => 'Oldest',
      StockSortType.name => 'Name',
      StockSortType.quantity => 'Qty',
      StockSortType.recentlyUpdated => 'Updated',
    };
  }
}

class StockInventoryState {
  const StockInventoryState({
    required this.stocks,
    required this.filteredStocks,
    required this.searchQuery,
    required this.selectedCategory,
    required this.selectedFilter,
    required this.selectedSort,
    required this.salesSummary,
    required this.isLoading,
    required this.isSavingSale,
    required this.successMessage,
    required this.errorMessage,
  });

  factory StockInventoryState.initial() {
    return StockInventoryState(
      stocks: const [],
      filteredStocks: const [],
      searchQuery: '',
      selectedCategory: null,
      selectedFilter: StockFilterType.all,
      selectedSort: StockSortType.recentlyUpdated,
      salesSummary: StockSalesSummaryModel.empty(),
      isLoading: true,
      isSavingSale: false,
      successMessage: null,
      errorMessage: null,
    );
  }

  final List<StockModel> stocks;
  final List<StockModel> filteredStocks;
  final String searchQuery;
  final StockCategory? selectedCategory;
  final StockFilterType selectedFilter;
  final StockSortType selectedSort;
  final StockSalesSummaryModel salesSummary;
  final bool isLoading;
  final bool isSavingSale;
  final String? successMessage;
  final String? errorMessage;

  StockInventoryState copyWith({
    List<StockModel>? stocks,
    List<StockModel>? filteredStocks,
    String? searchQuery,
    Object? selectedCategory = _noChange,
    StockFilterType? selectedFilter,
    StockSortType? selectedSort,
    StockSalesSummaryModel? salesSummary,
    bool? isLoading,
    bool? isSavingSale,
    Object? successMessage = _noChange,
    Object? errorMessage = _noChange,
  }) {
    return StockInventoryState(
      stocks: stocks ?? this.stocks,
      filteredStocks: filteredStocks ?? this.filteredStocks,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory == _noChange
          ? this.selectedCategory
          : selectedCategory as StockCategory?,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      selectedSort: selectedSort ?? this.selectedSort,
      salesSummary: salesSummary ?? this.salesSummary,
      isLoading: isLoading ?? this.isLoading,
      isSavingSale: isSavingSale ?? this.isSavingSale,
      successMessage: successMessage == _noChange
          ? this.successMessage
          : successMessage as String?,
      errorMessage: errorMessage == _noChange
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const _noChange = Object();
