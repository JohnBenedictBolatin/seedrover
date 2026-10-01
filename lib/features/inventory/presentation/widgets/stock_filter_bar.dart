import 'package:flutter/material.dart';

import '../../controllers/stock_inventory_state.dart';
import '../../data/models/stock_model.dart';
import '../../../../shared/widgets/compact_search_filter_bar.dart';

class StockFilterBar extends StatelessWidget {
  const StockFilterBar({
    required this.searchQuery,
    required this.selectedCategory,
    required this.selectedFilter,
    required this.selectedSort,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onFilterChanged,
    required this.onSortChanged,
    super.key,
  });

  final String searchQuery;
  final StockCategory? selectedCategory;
  final StockFilterType selectedFilter;
  final StockSortType selectedSort;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<StockCategory?> onCategoryChanged;
  final ValueChanged<StockFilterType> onFilterChanged;
  final ValueChanged<StockSortType> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return CompactSearchFilterBar(
      searchQuery: searchQuery,
      onSearchChanged: onSearchChanged,
      groups: [
        SearchFilterGroup(
          keyName: 'category',
          label: 'Category',
          initialValue: 'all',
          currentValue: selectedCategory?.name ?? 'all',
          options: [
            const SearchFilterOption('all', 'All categories'),
            for (final value in StockCategory.values)
              SearchFilterOption(value.name, value.label),
          ],
        ),
        SearchFilterGroup(
          keyName: 'status',
          label: 'Stock status',
          initialValue: StockFilterType.all.name,
          currentValue: selectedFilter.name,
          options: [
            for (final value in StockFilterType.values)
              SearchFilterOption(value.name, value.label)
          ],
        ),
        SearchFilterGroup(
          keyName: 'sort',
          label: 'Sort by',
          initialValue: StockSortType.recentlyUpdated.name,
          currentValue: selectedSort.name,
          options: [
            for (final value in StockSortType.values)
              SearchFilterOption(value.name, value.label)
          ],
        ),
      ],
      onApply: (values) {
        final category = values['category'];
        onCategoryChanged(category == 'all'
            ? null
            : StockCategory.values
                .firstWhere((value) => value.name == category));
        onFilterChanged(StockFilterType.values
            .firstWhere((value) => value.name == values['status']));
        onSortChanged(StockSortType.values
            .firstWhere((value) => value.name == values['sort']));
      },
    );
  }
}
