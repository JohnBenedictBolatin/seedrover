import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Compact range and previous/next controls shared by history sheets.
class HistoryPagination extends StatelessWidget {
  const HistoryPagination({
    required this.pageIndex,
    required this.totalRecords,
    required this.pageSize,
    required this.onPageChanged,
    super.key,
  });

  final int pageIndex;
  final int totalRecords;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final pageCount = totalRecords == 0 ? 1 : (totalRecords / pageSize).ceil();
    final firstRecord = totalRecords == 0 ? 0 : pageIndex * pageSize + 1;
    final lastRecord = ((pageIndex + 1) * pageSize).clamp(0, totalRecords);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              totalRecords == 0
                  ? 'No records'
                  : '$firstRecord–$lastRecord of $totalRecords records',
              style: AppTypography.caption,
            ),
          ),
          IconButton(
            tooltip: 'Previous page',
            onPressed:
                pageIndex <= 0 ? null : () => onPageChanged(pageIndex - 1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: pageIndex >= pageCount - 1
                ? null
                : () => onPageChanged(pageIndex + 1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}
