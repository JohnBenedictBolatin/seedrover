import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/crop_model.dart';

class CropFilterBar extends StatelessWidget {
  const CropFilterBar({
    required this.searchQuery,
    required this.selectedCropName,
    required this.selectedPlantingDate,
    required this.selectedGrowthStage,
    required this.cropNames,
    required this.plantingDates,
    required this.onSearchChanged,
    required this.onCropNameChanged,
    required this.onPlantingDateChanged,
    required this.onGrowthStageChanged,
    required this.onClear,
    super.key,
  });

  final String searchQuery;
  final String? selectedCropName;
  final DateTime? selectedPlantingDate;
  final CropGrowthStage? selectedGrowthStage;
  final List<String> cropNames;
  final List<DateTime> plantingDates;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCropNameChanged;
  final ValueChanged<DateTime?> onPlantingDateChanged;
  final ValueChanged<CropGrowthStage?> onGrowthStageChanged;
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
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _FilterSlot(
              child: _CompactFilterButton(
                icon: Icons.spa_outlined,
                label: selectedCropName ?? 'Plant',
                items: [
                  _CompactFilterItem(
                    label: 'All Plants',
                    onSelected: () => onCropNameChanged(null),
                  ),
                  for (final cropName in cropNames)
                    _CompactFilterItem(
                      label: cropName,
                      onSelected: () => onCropNameChanged(cropName),
                    ),
                ],
              ),
            ),
            _FilterSlot(
              child: _CompactFilterButton(
                icon: CupertinoIcons.calendar,
                label: selectedPlantingDate == null
                    ? 'Date'
                    : _formatShortDate(selectedPlantingDate!),
                items: [
                  _CompactFilterItem(
                    label: 'All Dates',
                    onSelected: () => onPlantingDateChanged(null),
                  ),
                  for (final date in plantingDates)
                    _CompactFilterItem(
                      label: _formatDate(date),
                      onSelected: () => onPlantingDateChanged(date),
                    ),
                ],
              ),
            ),
            _FilterSlot(
              child: _CompactFilterButton(
                icon: CupertinoIcons.chart_bar_alt_fill,
                label: selectedGrowthStage?.label ?? 'Stages',
                items: [
                  _CompactFilterItem(
                    label: 'All Stages',
                    onSelected: () => onGrowthStageChanged(null),
                  ),
                  for (final stage in CropGrowthStage.values)
                    _CompactFilterItem(
                      label: stage.label,
                      onSelected: () => onGrowthStageChanged(stage),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatShortDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year.toString().substring(2)}';
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
        hintText: 'Search crops',
      ),
    );
  }
}
