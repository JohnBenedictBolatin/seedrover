import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/profile_user_model.dart';

class ProfileUserFilterBar extends StatelessWidget {
  const ProfileUserFilterBar({
    required this.searchQuery,
    required this.selectedFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onClear,
    this.leading,
    super.key,
  });

  final String searchQuery;
  final ProfileUserFilter selectedFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ProfileUserFilter> onFilterChanged;
  final VoidCallback onClear;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SearchField(
          searchQuery: searchQuery,
          onChanged: onSearchChanged,
          onClear: onClear,
        ),
        const SizedBox(height: AppSpacing.md),
        if (leading == null)
          Align(
            alignment: Alignment.center,
            child: _UserFilterButton(
              selectedFilter: selectedFilter,
              onFilterChanged: onFilterChanged,
            ),
          )
        else
          Row(
            children: [
              leading!,
              const Spacer(),
              _UserFilterButton(
                selectedFilter: selectedFilter,
                onFilterChanged: onFilterChanged,
              ),
            ],
          ),
      ],
    );
  }
}

class _UserFilterButton extends StatelessWidget {
  const _UserFilterButton({
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final ProfileUserFilter selectedFilter;
  final ValueChanged<ProfileUserFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: _FilterButton(
        label: selectedFilter.label,
        icon: CupertinoIcons.slider_horizontal_3,
        items: [
          for (final filter in ProfileUserFilter.values)
            _FilterItem(
              label: filter.label,
              onSelected: () => onFilterChanged(filter),
            ),
        ],
      ),
    );
  }
}

class ActivityFilterBar extends StatelessWidget {
  const ActivityFilterBar({
    required this.selectedFilter,
    required this.onFilterChanged,
    super.key,
  });

  final ProfileActivityFilter selectedFilter;
  final ValueChanged<ProfileActivityFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: _FilterButton(
        label: selectedFilter.label,
        icon: CupertinoIcons.calendar,
        items: [
          for (final filter in ProfileActivityFilter.values)
            _FilterItem(
              label: filter.label,
              onSelected: () => onFilterChanged(filter),
            ),
        ],
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.searchQuery,
    required this.onChanged,
    required this.onClear,
  });

  final String searchQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _SearchField oldWidget) {
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
      decoration: InputDecoration(
        hintText: 'Search users',
        prefixIcon: const Icon(CupertinoIcons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: widget.onClear,
                icon: const Icon(CupertinoIcons.xmark_circle),
              ),
      ),
    );
  }
}

class _FilterItem {
  const _FilterItem({
    required this.label,
    required this.onSelected,
  });

  final String label;
  final VoidCallback onSelected;
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.icon,
    required this.items,
  });

  final String label;
  final IconData icon;
  final List<_FilterItem> items;

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
