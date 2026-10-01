import 'package:flutter/material.dart';

import '../../data/models/notification_model.dart';
import '../../../../shared/widgets/compact_search_filter_bar.dart';

class NotificationFilterBar extends StatelessWidget {
  const NotificationFilterBar({
    required this.searchQuery,
    required this.selectedCategory,
    required this.selectedPriority,
    required this.selectedDate,
    required this.selectedSort,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onPriorityChanged,
    required this.onDateChanged,
    required this.onSortChanged,
    super.key,
  });

  final String searchQuery;
  final NotificationCategory? selectedCategory;
  final NotificationPriority? selectedPriority;
  final NotificationDateFilter selectedDate;
  final NotificationSortType selectedSort;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<NotificationCategory?> onCategoryChanged;
  final ValueChanged<NotificationPriority?> onPriorityChanged;
  final ValueChanged<NotificationDateFilter> onDateChanged;
  final ValueChanged<NotificationSortType> onSortChanged;

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
            for (final value in NotificationCategory.values)
              SearchFilterOption(value.name, value.label)
          ],
        ),
        SearchFilterGroup(
          keyName: 'priority',
          label: 'Priority',
          initialValue: 'all',
          currentValue: selectedPriority?.name ?? 'all',
          options: [
            const SearchFilterOption('all', 'All priorities'),
            for (final value in NotificationPriority.values)
              SearchFilterOption(value.name, value.label)
          ],
        ),
        SearchFilterGroup(
          keyName: 'date',
          label: 'Date',
          initialValue: NotificationDateFilter.all.name,
          currentValue: selectedDate.name,
          options: [
            for (final value in NotificationDateFilter.values)
              SearchFilterOption(value.name, value.label)
          ],
        ),
        SearchFilterGroup(
          keyName: 'sort',
          label: 'Sort by',
          initialValue: NotificationSortType.newest.name,
          currentValue: selectedSort.name,
          options: [
            for (final value in NotificationSortType.values)
              SearchFilterOption(value.name, value.label)
          ],
        ),
      ],
      onApply: (values) {
        final category = values['category'];
        final priority = values['priority'];
        onCategoryChanged(category == 'all'
            ? null
            : NotificationCategory.values
                .firstWhere((value) => value.name == category));
        onPriorityChanged(priority == 'all'
            ? null
            : NotificationPriority.values
                .firstWhere((value) => value.name == priority));
        onDateChanged(NotificationDateFilter.values
            .firstWhere((value) => value.name == values['date']));
        onSortChanged(NotificationSortType.values
            .firstWhere((value) => value.name == values['sort']));
      },
    );
  }
}
