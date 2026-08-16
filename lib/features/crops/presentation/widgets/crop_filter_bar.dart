import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../controllers/crop_monitoring_state.dart';

class CropFilterBar extends StatelessWidget {
  const CropFilterBar({
    required this.searchQuery,
    required this.selectedFilter,
    required this.selectedSort,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.onClear,
    super.key,
  });

  final String searchQuery;
  final CropFilterType selectedFilter;
  final CropSortType selectedSort;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<CropFilterType> onFilterChanged;
  final ValueChanged<CropSortType> onSortChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CropSearchField(
          searchQuery: searchQuery,
          onChanged: onSearchChanged,
          onClear: onClear,
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterSlot(
                child: _CompactFilterButton(
                  icon: Icons.filter_list,
                  label: selectedFilter.label,
                  items: [
                    for (final filter in CropFilterType.values)
                      _CompactFilterItem(
                        label: filter.label,
                        onSelected: () => onFilterChanged(filter),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _FilterSlot(
                child: _CompactFilterButton(
                  icon: CupertinoIcons.sort_down,
                  label: selectedSort.label,
                  items: [
                    for (final sort in CropSortType.values)
                      _CompactFilterItem(
                        label: sort.label,
                        onSelected: () => onSortChanged(sort),
                      ),
                  ],
                ),
              ),
            ],
          ),
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
    return SizedBox(width: 104, child: child);
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
            horizontal: AppSpacing.xs,
            vertical: 7,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: AppColors.primaryText),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                CupertinoIcons.chevron_down,
                size: 10,
                color: AppColors.primaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CropSearchField extends StatefulWidget {
  const _CropSearchField({
    required this.searchQuery,
    required this.onChanged,
    required this.onClear,
  });

  final String searchQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_CropSearchField> createState() => _CropSearchFieldState();
}

class _CropSearchFieldState extends State<_CropSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _CropSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.searchQuery != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.searchQuery,
        selection: TextSelection.collapsed(offset: widget.searchQuery.length),
      );
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
      onChanged: (value) {
        setState(() {});
        widget.onChanged(value);
      },
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 12,
        ),
        prefixIcon: const Icon(CupertinoIcons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  setState(_controller.clear);
                  widget.onClear();
                },
                icon: const Icon(CupertinoIcons.xmark_circle),
              ),
        hintText: 'Search crops',
      ),
    );
  }
}
