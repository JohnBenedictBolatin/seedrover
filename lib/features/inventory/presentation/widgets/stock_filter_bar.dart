import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../controllers/stock_inventory_state.dart';
import '../../data/models/stock_model.dart';

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
    required this.onClear,
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
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StockSearchField(
          searchQuery: searchQuery,
          onChanged: onSearchChanged,
          onClear: onClear,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _FilterSlot(
              child: _CompactFilterButton(
                icon: CupertinoIcons.cube_box,
                label: selectedCategory?.label ?? 'Category',
                items: [
                  _CompactFilterItem(
                    label: 'All Categories',
                    onSelected: () => onCategoryChanged(null),
                  ),
                  for (final category in StockCategory.values)
                    _CompactFilterItem(
                      label: category.label,
                      onSelected: () => onCategoryChanged(category),
                    ),
                ],
              ),
            ),
            _FilterSlot(
              child: _CompactFilterButton(
                icon: CupertinoIcons.check_mark_circled,
                label: selectedFilter.label,
                items: [
                  for (final filter in StockFilterType.values)
                    _CompactFilterItem(
                      label: filter.label,
                      onSelected: () => onFilterChanged(filter),
                    ),
                ],
              ),
            ),
            _FilterSlot(
              child: _CompactFilterButton(
                icon: Icons.sort,
                label: selectedSort.label,
                items: [
                  for (final sort in StockSortType.values)
                    _CompactFilterItem(
                      label: sort.label,
                      onSelected: () => onSortChanged(sort),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterSlot extends StatelessWidget {
  const _FilterSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 112, child: child);
  }
}

class _CompactFilterItem {
  const _CompactFilterItem({
    required this.label,
    required this.onSelected,
  });

  final String label;
  final VoidCallback onSelected;
}

class _CompactFilterButton extends StatelessWidget {
  const _CompactFilterButton({
    required this.icon,
    required this.label,
    required this.items,
  });

  final IconData icon;
  final String label;
  final List<_CompactFilterItem> items;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: label,
      color: AppColors.secondaryBackground,
      onSelected: (index) => items[index].onSelected(),
      itemBuilder: (context) {
        return [
          for (var index = 0; index < items.length; index++)
            PopupMenuItem<int>(
              value: index,
              child: Text(items[index].label, style: AppTypography.body),
            ),
        ];
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          border: Border.all(color: AppColors.inactiveBorder),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: AppColors.primaryText),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                CupertinoIcons.chevron_down,
                size: 12,
                color: AppColors.primaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockSearchField extends StatefulWidget {
  const _StockSearchField({
    required this.searchQuery,
    required this.onChanged,
    required this.onClear,
  });

  final String searchQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_StockSearchField> createState() => _StockSearchFieldState();
}

class _StockSearchFieldState extends State<_StockSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _StockSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.searchQuery != _controller.text) {
      _controller.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon: const Icon(CupertinoIcons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: widget.onClear,
                icon: const Icon(CupertinoIcons.xmark_circle),
              ),
        hintText: 'Search inventory',
      ),
    );
  }
}
