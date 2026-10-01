import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class SearchFilterOption {
  const SearchFilterOption(this.value, this.label);
  final String value;
  final String label;
}

class SearchFilterGroup {
  const SearchFilterGroup({
    required this.keyName,
    required this.label,
    required this.options,
    required this.initialValue,
    this.currentValue,
  });
  final String keyName;
  final String label;
  final List<SearchFilterOption> options;
  final String initialValue;
  final String? currentValue;
}

/// Shared compact search with filters and sorting applied from one sheet.
class CompactSearchFilterBar extends StatelessWidget {
  const CompactSearchFilterBar({
    required this.searchQuery,
    required this.groups,
    required this.onSearchChanged,
    required this.onApply,
    super.key,
  });

  final String searchQuery;
  final List<SearchFilterGroup> groups;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Map<String, String>> onApply;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: _CompactSearchInput(
                  query: searchQuery, onChanged: onSearchChanged),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              key: const Key('open-filter-sheet'),
              onPressed: () => _showSheet(context),
              icon: Badge(
                isLabelVisible: groups.any((group) =>
                    (group.currentValue ?? group.initialValue) !=
                    group.initialValue),
                smallSize: 8,
                backgroundColor: AppColors.primaryGreen,
                child: const Icon(Icons.tune, size: 18),
              ),
              label: const Text('Filter'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd),
                side: BorderSide(color: AppColors.inactiveBorder),
              ),
            ),
          ),
        ],
      );

  Future<void> _showSheet(BuildContext context) async {
    final defaults = {
      for (final group in groups) group.keyName: group.initialValue
    };
    final selected = {
      for (final group in groups)
        group.keyName: group.currentValue ?? group.initialValue
    };
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _SearchFilterSheet(
          groups: groups, defaults: defaults, selected: selected),
    );
    if (result != null) onApply(result);
  }
}

class _CompactSearchInput extends StatefulWidget {
  const _CompactSearchInput({required this.query, required this.onChanged});
  final String query;
  final ValueChanged<String> onChanged;

  @override
  State<_CompactSearchInput> createState() => _CompactSearchInputState();
}

class _CompactSearchInputState extends State<_CompactSearchInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _CompactSearchInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query && widget.query != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        key: const Key('compact-search-field'),
        controller: _controller,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: widget.query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                  },
                  icon: const Icon(Icons.close, size: 18),
                ),
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
      );
}

class _SearchFilterSheet extends StatefulWidget {
  const _SearchFilterSheet(
      {required this.groups, required this.defaults, required this.selected});
  final List<SearchFilterGroup> groups;
  final Map<String, String> defaults;
  final Map<String, String> selected;

  @override
  State<_SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<_SearchFilterSheet> {
  late Map<String, String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Map.of(widget.selected);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter and sort', style: AppTypography.screenTitle),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final group in widget.groups) ...[
                      Text(group.label, style: AppTypography.sectionHeading),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final option in group.options)
                            ChoiceChip(
                              label: Text(option.label),
                              selected:
                                  _selected[group.keyName] == option.value,
                              onSelected: (_) => setState(() =>
                                  _selected[group.keyName] = option.value),
                              showCheckmark: false,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              selectedColor: AppColors.sageSurface,
                              side: BorderSide(color: AppColors.inactiveBorder),
                              labelStyle: AppTypography.small.copyWith(
                                color: _selected[group.keyName] == option.value
                                    ? AppColors.secondaryGreen
                                    : AppColors.primaryText,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, widget.defaults),
                  child: const Text('Reset'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: const Text('Apply filters'),
                ),
              ],
            ),
          ],
        ),
      );
}
