import 'package:flutter/material.dart';

import '../../controllers/crop_monitoring_state.dart';
import '../../../../shared/widgets/compact_search_filter_bar.dart';

class CropFilterBar extends StatelessWidget {
  const CropFilterBar({
    required this.searchQuery,
    required this.selectedFilter,
    required this.selectedSort,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onSortChanged,
    super.key,
  });

  final String searchQuery;
  final CropFilterType selectedFilter;
  final CropSortType selectedSort;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<CropFilterType> onFilterChanged;
  final ValueChanged<CropSortType> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return CompactSearchFilterBar(
      searchQuery: searchQuery,
      onSearchChanged: onSearchChanged,
      groups: [
        SearchFilterGroup(
          keyName: 'status',
          label: 'Crop status',
          initialValue: CropFilterType.all.name,
          currentValue: selectedFilter.name,
          options: [
            for (final value in CropFilterType.values)
              SearchFilterOption(value.name, value.label)
          ],
        ),
        SearchFilterGroup(
          keyName: 'sort',
          label: 'Sort by',
          initialValue: CropSortType.newest.name,
          currentValue: selectedSort.name,
          options: [
            for (final value in CropSortType.values)
              SearchFilterOption(value.name, value.label)
          ],
        ),
      ],
      onApply: (values) {
        onFilterChanged(CropFilterType.values
            .firstWhere((value) => value.name == values['status']));
        onSortChanged(CropSortType.values
            .firstWhere((value) => value.name == values['sort']));
      },
    );
  }
}
