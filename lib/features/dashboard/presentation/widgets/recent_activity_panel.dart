import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/models/dashboard_model.dart';

class RecentActivityPanel extends StatelessWidget {
  const RecentActivityPanel({
    required this.activities,
    super.key,
  });

  final List<ActivityPreviewModel> activities;

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
        if (previewActivities.isEmpty)
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
    showDialog<void>(
      context: context,
      builder: (_) => _ActivityHistoryDialog(activities: activities),
    );
  }
}

class _ActivityHistoryDialog extends StatefulWidget {
  const _ActivityHistoryDialog({required this.activities});

  final List<ActivityPreviewModel> activities;

  @override
  State<_ActivityHistoryDialog> createState() => _ActivityHistoryDialogState();
}

class _ActivityHistoryDialogState extends State<_ActivityHistoryDialog> {
  static const int _pageSize = 6;

  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final totalPages = widget.activities.isEmpty
        ? 1
        : ((widget.activities.length + _pageSize - 1) ~/ _pageSize);
    final startIndex = _page * _pageSize;
    final pageActivities =
        widget.activities.skip(startIndex).take(_pageSize).toList();
    final maxContentHeight = MediaQuery.of(context).size.height * 0.62;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: AppCard(
        backgroundColor: AppColors.secondaryBackground,
        borderColor: AppColors.inactiveBorder,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Activities',
                        style: AppTypography.cardTitle.copyWith(
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${widget.activities.length} activity records',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxContentHeight),
              child: pageActivities.isEmpty
                  ? const _RecentActivityEmptyState()
                  : ListView.separated(
                      shrinkWrap: true,
                      itemBuilder: (_, index) => _RecentActivityTile(
                        activity: pageActivities[index],
                      ),
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemCount: pageActivities.length,
                    ),
            ),
            if (widget.activities.length > _pageSize) ...[
              const SizedBox(height: AppSpacing.lg),
              _ActivityPager(
                currentPage: _page + 1,
                totalPages: totalPages,
                onPrevious: _page == 0
                    ? null
                    : () => setState(() => _page -= 1),
                onNext: _page >= totalPages - 1
                    ? null
                    : () => setState(() => _page += 1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityPager extends StatelessWidget {
  const _ActivityPager({
    required this.currentPage,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.primaryGreen.withOpacity(0.16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            _PagerButton(
              icon: Icons.chevron_left_rounded,
              onPressed: onPrevious,
            ),
            Expanded(
              child: Text(
                'Page $currentPage of $totalPages',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _PagerButton(
              icon: Icons.chevron_right_rounded,
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      color: enabled ? AppColors.primaryGreen : AppColors.mutedText,
      style: IconButton.styleFrom(
        backgroundColor: enabled
            ? AppColors.primaryGreen.withOpacity(0.12)
            : AppColors.cardBackground.withOpacity(0.72),
        shape: const CircleBorder(),
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
                color: AppColors.primaryGreen.withOpacity(0.10),
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
          color: AppColors.primaryGreen.withOpacity(0.14),
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
                color: AppColors.primaryGreen.withOpacity(0.10),
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
                    '${activity.module} - '
                    '${DateTimeFormatter.formatTime(activity.timestamp)}',
                    style: AppTypography.monoCaption,
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
