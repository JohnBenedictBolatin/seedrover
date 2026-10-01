import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../../../shared/widgets/history_pagination.dart';
import '../../data/models/dashboard_model.dart';

class RecentActivityPanel extends StatelessWidget {
  const RecentActivityPanel({
    required this.activities,
    this.errorMessage,
    super.key,
  });

  final List<ActivityPreviewModel> activities;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final previewActivities = activities.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent Activities',
                style: AppTypography.cardTitle.copyWith(fontSize: 16),
              ),
            ),
            if (activities.length > 3)
              TextButton(
                onPressed: () => _showAllActivities(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: AppTypography.small.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (errorMessage != null)
          Text(errorMessage!, style: AppTypography.caption)
        else if (previewActivities.isEmpty)
          const _RecentActivityEmptyState()
        else
          for (var index = 0; index < previewActivities.length; index++) ...[
            _RecentActivityTile(activity: previewActivities[index]),
            if (index != previewActivities.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }

  void _showAllActivities(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActivityHistorySheet(activities: activities),
    );
  }
}

class _ActivityHistorySheet extends StatefulWidget {
  const _ActivityHistorySheet({required this.activities});

  final List<ActivityPreviewModel> activities;

  @override
  State<_ActivityHistorySheet> createState() => _ActivityHistorySheetState();
}

class _ActivityHistorySheetState extends State<_ActivityHistorySheet> {
  static const int _pageSize = 5;

  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final startIndex = _page * _pageSize;
    final pageActivities =
        widget.activities.skip(startIndex).take(_pageSize).toList();
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: .88,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primaryBackground,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                key: const Key('recent-activity-history-drag-handle'),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.inactiveBorder,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Recent Activities',
                              style: AppTypography.sectionHeading),
                          Text('${widget.activities.length} activity records',
                              style: AppTypography.caption),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close recent activities',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: pageActivities.isEmpty
                    ? const _RecentActivityEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.xs,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        itemBuilder: (_, index) => _RecentActivityTile(
                          activity: pageActivities[index],
                        ),
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemCount: pageActivities.length,
                      ),
              ),
              if (widget.activities.length > _pageSize)
                HistoryPagination(
                  pageIndex: _page,
                  totalRecords: widget.activities.length,
                  pageSize: _pageSize,
                  onPageChanged: (page) => setState(() => _page = page),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivityEmptyState extends StatelessWidget {
  const _RecentActivityEmptyState();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.inactiveBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                Icons.history_toggle_off_rounded,
                color: AppColors.primaryGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'No recent activities yet.',
                style: AppTypography.small,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityTile extends StatelessWidget {
  const _RecentActivityTile({required this.activity});

  final ActivityPreviewModel activity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.14),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                Icons.schedule_rounded,
                color: AppColors.primaryGreen,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(activity.title, style: AppTypography.cardTitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(activity.description, style: AppTypography.small),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    activity.timestamp == null
                        ? activity.module
                        : '${activity.module} - ${DateTimeFormatter.formatTime(activity.timestamp!)}',
                    style: AppTypography.numericCaption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
