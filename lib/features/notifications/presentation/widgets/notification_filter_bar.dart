import 'package:flutter/material.dart';

import '../../data/models/notification_model.dart';
import '../../../../shared/widgets/compact_search_filter_bar.dart';

class NotificationFilterBar extends StatelessWidget {
  const NotificationFilterBar({
    required this.searchQuery,
    required this.selectedCategory,
    required this.selectedStatus,
    required this.selectedDate,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onStatusChanged,
    required this.onDateChanged,
    super.key,
  });

  final String searchQuery;
  final NotificationCategory? selectedCategory;
  final NotificationStatusFilter selectedStatus;
  final NotificationDateFilter selectedDate;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<NotificationCategory?> onCategoryChanged;
  final ValueChanged<NotificationStatusFilter> onStatusChanged;
  final ValueChanged<NotificationDateFilter> onDateChanged;

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
          keyName: 'status',
          label: 'Read status',
          initialValue: NotificationStatusFilter.all.name,
          currentValue: selectedStatus.name,
          options: [
            for (final value in NotificationStatusFilter.values)
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
      ],
      onApply: (values) {
        final category = values['category'];
        onCategoryChanged(category == 'all'
            ? null
            : NotificationCategory.values
                .firstWhere((value) => value.name == category));
        onStatusChanged(NotificationStatusFilter.values
            .firstWhere((value) => value.name == values['status']));
        onDateChanged(NotificationDateFilter.values
            .firstWhere((value) => value.name == values['date']));
      },
    );
  }
}
