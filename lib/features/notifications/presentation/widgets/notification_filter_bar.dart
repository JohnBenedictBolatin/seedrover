import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/notification_model.dart';

class NotificationFilterBar extends StatelessWidget {
  const NotificationFilterBar({
    required this.searchQuery,
    required this.selectedCategory,
    required this.selectedPriority,
    required this.selectedStatus,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onPriorityChanged,
    required this.onStatusChanged,
    required this.onClear,
    super.key,
  });

  final String searchQuery;
  final NotificationCategory? selectedCategory;
  final NotificationPriority? selectedPriority;
  final NotificationStatusFilter selectedStatus;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<NotificationCategory?> onCategoryChanged;
  final ValueChanged<NotificationPriority?> onPriorityChanged;
  final ValueChanged<NotificationStatusFilter> onStatusChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NotificationSearchField(
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
                icon: CupertinoIcons.square_grid_2x2,
                label: selectedCategory?.label ?? 'Category',
                items: [
                  _CompactFilterItem(
                    label: 'All Categories',
                    onSelected: () => onCategoryChanged(null),
                  ),
                  for (final category in NotificationCategory.values)
                    _CompactFilterItem(
                      label: category.label,
                      onSelected: () => onCategoryChanged(category),
                    ),
                ],
              ),
            ),
            _FilterSlot(
              child: _CompactFilterButton(
                icon: CupertinoIcons.exclamationmark_circle,
                label: selectedPriority?.label ?? 'Priority',
                items: [
                  _CompactFilterItem(
                    label: 'All Priorities',
                    onSelected: () => onPriorityChanged(null),
                  ),
                  for (final priority in NotificationPriority.values)
                    _CompactFilterItem(
                      label: priority.label,
                      onSelected: () => onPriorityChanged(priority),
                    ),
                ],
              ),
            ),
            _FilterSlot(
              child: _CompactFilterButton(
                icon: CupertinoIcons.check_mark_circled,
                label: selectedStatus.label,
                items: [
                  for (final status in NotificationStatusFilter.values)
                    _CompactFilterItem(
                      label: status.label,
                      onSelected: () => onStatusChanged(status),
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

class _NotificationSearchField extends StatefulWidget {
  const _NotificationSearchField({
    required this.searchQuery,
    required this.onChanged,
    required this.onClear,
  });

  final String searchQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_NotificationSearchField> createState() =>
      _NotificationSearchFieldState();
}

class _NotificationSearchFieldState extends State<_NotificationSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _NotificationSearchField oldWidget) {
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
        hintText: 'Search notifications',
      ),
    );
  }
}
