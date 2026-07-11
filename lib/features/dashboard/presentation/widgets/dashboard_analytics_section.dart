import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../features/crops/data/models/crop_model.dart';
import '../../../../features/crops/providers/crop_providers.dart';
import '../../../../features/inventory/data/models/stock_model.dart';
import '../../../../features/inventory/providers/stock_providers.dart';
import '../../../../shared/widgets/animated_content.dart';
import '../../../../shared/widgets/app_card.dart';

class DashboardAnalyticsSection extends ConsumerStatefulWidget {
  const DashboardAnalyticsSection({super.key});

  @override
  ConsumerState<DashboardAnalyticsSection> createState() =>
      _DashboardAnalyticsSectionState();
}

class _DashboardAnalyticsSectionState
    extends ConsumerState<DashboardAnalyticsSection> {
  _AnalyticsRange _selectedRange = _AnalyticsRange.month;

  @override
  Widget build(BuildContext context) {
    final crops = ref.watch(cropMonitoringControllerProvider).crops;
    final stocks = ref.watch(stockInventoryControllerProvider).stocks;
    final analytics = _DashboardAnalytics.from(
      crops: crops,
      stocks: stocks,
      range: _selectedRange,
    );

    return AppCard(
      backgroundColor: AppColors.secondaryBackground,
      borderColor: AppColors.inactiveBorder,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: AnimatedTypingText(
                  'Farm Analytics',
                  style: AppTypography.sectionHeading,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _AnalyticsRangeFilter(
                selectedRange: _selectedRange,
                onChanged: (range) {
                  setState(() => _selectedRange = range);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 640;

              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _KpiCard(
                    width: compact
                        ? (constraints.maxWidth - AppSpacing.md) / 2
                        : (constraints.maxWidth - AppSpacing.md * 3) / 4,
                    label: 'Crops',
                    value: analytics.totalCrops.toString(),
                    caption: 'records',
                    color: AppColors.primaryGreen,
                    icon: Icons.spa_outlined,
                  ),
                  _KpiCard(
                    width: compact
                        ? (constraints.maxWidth - AppSpacing.md) / 2
                        : (constraints.maxWidth - AppSpacing.md * 3) / 4,
                    label: 'Seeds',
                    value: analytics.totalSeeds.toString(),
                    caption: 'planted',
                    color: AppColors.accentGreen,
                    icon: Icons.grass_outlined,
                  ),
                  _KpiCard(
                    width: compact
                        ? (constraints.maxWidth - AppSpacing.md) / 2
                        : (constraints.maxWidth - AppSpacing.md * 3) / 4,
                    label: 'Sold',
                    value: _formatAnalyticsQuantity(analytics.totalSold),
                    caption: 'units',
                    color: AppColors.information,
                    icon: Icons.sell_outlined,
                  ),
                  _KpiCard(
                    width: compact
                        ? (constraints.maxWidth - AppSpacing.md) / 2
                        : (constraints.maxWidth - AppSpacing.md * 3) / 4,
                    label: 'Top Item',
                    value: analytics.topSoldItemCount,
                    caption: analytics.topSoldItem,
                    color: AppColors.warning,
                    icon: Icons.emoji_events_outlined,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 760;
              final chartWidth = twoColumns
                  ? (constraints.maxWidth - AppSpacing.md) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  SizedBox(
                    width: chartWidth,
                    child: _AnalyticsChartCard(
                      title: 'Crops Planted',
                      subtitle: '${analytics.rangeLabel} by seed type',
                      icon: Icons.spa_outlined,
                      child: _BarChart(
                        entries: analytics.cropsByName,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: chartWidth,
                    child: _AnalyticsChartCard(
                      title: 'Products Sold',
                      subtitle: '${analytics.rangeLabel} stock out',
                      icon: Icons.sell_outlined,
                      child: _BarChart(
                        entries: analytics.soldByItem,
                        color: AppColors.information,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: chartWidth,
                    child: _AnalyticsChartCard(
                      title: 'Crop Progress',
                      subtitle: '${analytics.rangeLabel} average by seed type',
                      icon: Icons.timeline,
                      child: _BarChart(
                        entries: analytics.averageProgressByName,
                        color: AppColors.accentGreen,
                        suffix: '%',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: chartWidth,
                    child: _AnalyticsChartCard(
                      title: 'Sales Trend',
                      subtitle: analytics.trendLabel,
                      icon: Icons.show_chart,
                      child: _LineChart(entries: analytics.salesTrend),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

}

enum _AnalyticsRange {
  week('Week'),
  month('Month'),
  year('Year');

  const _AnalyticsRange(this.label);

  final String label;
}

class _AnalyticsRangeFilter extends StatelessWidget {
  const _AnalyticsRangeFilter({
    required this.selectedRange,
    required this.onChanged,
  });

  final _AnalyticsRange selectedRange;
  final ValueChanged<_AnalyticsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border.all(color: AppColors.inactiveBorder),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final range in _AnalyticsRange.values)
              _RangeButton(
                label: range.label,
                selected: selectedRange == range,
                onTap: () => onChanged(range),
              ),
          ],
        ),
      ),
    );
  }
}

class _RangeButton extends StatelessWidget {
  const _RangeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.cardBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected ? AppColors.primaryGreen : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.statusBadge.copyWith(
            color: selected ? AppColors.primaryGreen : AppColors.secondaryText,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.width,
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final String caption;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width.clamp(132, double.infinity).toDouble(),
      child: AppCard(
        backgroundColor: AppColors.secondaryBackground,
        borderColor: AppColors.inactiveBorder,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedTypingText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: AnimatedMetricText(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sectionHeading.copyWith(color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            AnimatedTypingText(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.monoCaption,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsChartCard extends StatelessWidget {
  const _AnalyticsChartCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.secondaryBackground,
      borderColor: AppColors.inactiveBorder,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryGreen, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: AnimatedTypingText(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cardTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          AnimatedTypingText(subtitle, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.entries,
    required this.color,
    this.suffix = '',
  });

  final List<_ChartEntry> entries;
  final Color color;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text('No chart data yet.', style: AppTypography.caption);
    }

    final maxValue = entries.fold<double>(
      1,
      (maxValue, entry) => math.max(maxValue, entry.value),
    );

    return Column(
      children: [
        for (final entry in entries.take(5)) ...[
          Row(
            children: [
              SizedBox(
                width: 82,
                child: AnimatedTypingText(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: entry.value / maxValue),
                    duration: const Duration(milliseconds: 820),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return LinearProgressIndicator(
                        value: value.clamp(0, 1).toDouble(),
                        minHeight: 10,
                        color: color,
                        backgroundColor: AppColors.cardBackground,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 48,
                child: AnimatedMetricText(
                  '${_formatAnalyticsQuantity(entry.value)}$suffix',
                  textAlign: TextAlign.end,
                  style: AppTypography.monoCaption.copyWith(
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.entries});

  final List<_ChartEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return SizedBox(
        height: 150,
        child: Center(
          child: Text('No sales trend yet.', style: AppTypography.caption),
        ),
      );
    }

    return SizedBox(
      height: 150,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, progress, child) {
          return CustomPaint(
            painter: _LineChartPainter(entries: entries, progress: progress),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final entry in entries)
                    Text(entry.label, style: AppTypography.monoCaption),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.entries,
    required this.progress,
  });

  final List<_ChartEntry> entries;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) {
      return;
    }

    final chartHeight = size.height - 26;
    final maxValue = entries.fold<double>(
      1,
      (maxValue, entry) => math.max(maxValue, entry.value),
    );
    final linePaint = Paint()
      ..color = AppColors.primaryGreen
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = AppColors.primaryGreen.withOpacity(0.12)
      ..style = PaintingStyle.fill;
    final gridPaint = Paint()
      ..color = AppColors.inactiveBorder.withOpacity(0.45)
      ..strokeWidth = 1;
    final dotPaint = Paint()
      ..color = AppColors.accentGreen
      ..style = PaintingStyle.fill;

    for (var index = 0; index < 3; index++) {
      final y = chartHeight * (index / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    final fillPath = Path();

    for (var index = 0; index < entries.length; index++) {
      final x = entries.length == 1
          ? size.width / 2
          : (size.width / (entries.length - 1)) * index;
      final normalized = entries[index].value / maxValue;
      final y = chartHeight - (chartHeight * normalized * progress);

      if (index == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chartHeight);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }

    fillPath.lineTo(size.width, chartHeight);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.entries != entries || oldDelegate.progress != progress;
  }
}

class _DashboardAnalytics {
  const _DashboardAnalytics({
    required this.totalCrops,
    required this.totalSeeds,
    required this.totalSold,
    required this.topSoldItem,
    required this.topSoldItemCount,
    required this.rangeLabel,
    required this.trendLabel,
    required this.cropsByName,
    required this.averageProgressByName,
    required this.soldByItem,
    required this.salesTrend,
  });

  final int totalCrops;
  final int totalSeeds;
  final double totalSold;
  final String topSoldItem;
  final String topSoldItemCount;
  final String rangeLabel;
  final String trendLabel;
  final List<_ChartEntry> cropsByName;
  final List<_ChartEntry> averageProgressByName;
  final List<_ChartEntry> soldByItem;
  final List<_ChartEntry> salesTrend;

  factory _DashboardAnalytics.from({
    required List<CropModel> crops,
    required List<StockModel> stocks,
    required _AnalyticsRange range,
  }) {
    final cropCounts = <String, double>{};
    final seedCounts = <String, double>{};
    final progressTotals = <String, double>{};
    final soldByItem = <String, double>{};
    final trendByDay = <DateTime, double>{};
    final referenceDate = _latestDataDate(crops, stocks) ?? DateTime.now();
    final rangeStart = _rangeStart(referenceDate, range);
    final filteredCrops = crops
        .where((crop) => !_isBeforeDay(crop.plantingDate, rangeStart))
        .toList();

    for (final crop in filteredCrops) {
      cropCounts.update(crop.name, (value) => value + 1, ifAbsent: () => 1);
      seedCounts.update(
        crop.name,
        (value) => value + crop.safeSeedCount,
        ifAbsent: () => crop.safeSeedCount.toDouble(),
      );
      progressTotals.update(
        crop.name,
        (value) => value + crop.progress,
        ifAbsent: () => crop.progress,
      );
    }

    final trendBuckets = _trendBuckets(referenceDate, range);

    for (final day in trendBuckets) {
      trendByDay[day] = 0;
    }

    for (final stock in stocks) {
      for (final transaction in stock.transactions) {
        if (transaction.type != StockTransactionType.stockOut) {
          continue;
        }

        if (_isBeforeDay(transaction.performedAt, rangeStart)) {
          continue;
        }

        soldByItem.update(
          stock.name,
          (value) => value + transaction.quantity,
          ifAbsent: () => transaction.quantity,
        );

        final trendKey = _trendKeyFor(
          date: transaction.performedAt,
          range: range,
          buckets: trendBuckets,
        );

        if (trendKey != null) {
          trendByDay[trendKey] = trendByDay[trendKey]! + transaction.quantity;
        }
      }
    }

    final cropProgress = [
      for (final entry in progressTotals.entries)
        _ChartEntry(
          entry.key,
          ((entry.value / (cropCounts[entry.key] ?? 1)) * 100).roundToDouble(),
        ),
    ]..sort((left, right) => right.value.compareTo(left.value));
    final sales = _entriesFromMap(soldByItem);
    final topSale = sales.isEmpty ? null : sales.first;

    return _DashboardAnalytics(
      totalCrops: filteredCrops.length,
      totalSeeds: filteredCrops.fold<int>(
        0,
        (total, crop) => total + crop.safeSeedCount,
      ),
      totalSold: soldByItem.values.fold<double>(0, (total, value) => total + value),
      topSoldItem: topSale?.label ?? 'None',
      topSoldItemCount:
          topSale == null ? '0' : _formatAnalyticsQuantity(topSale.value),
      rangeLabel: range.label,
      trendLabel: _trendLabel(range),
      cropsByName: _entriesFromMap(seedCounts),
      averageProgressByName: cropProgress,
      soldByItem: sales,
      salesTrend: [
        for (final entry in trendByDay.entries)
          _ChartEntry(_trendBucketLabel(entry.key, range), entry.value),
      ],
    );
  }

  static List<_ChartEntry> _entriesFromMap(Map<String, double> source) {
    return [
      for (final entry in source.entries) _ChartEntry(entry.key, entry.value),
    ]..sort((left, right) => right.value.compareTo(left.value));
  }

  static DateTime? _latestDataDate(List<CropModel> crops, List<StockModel> stocks) {
    DateTime? latest;

    void visit(DateTime date) {
      if (latest == null || date.isAfter(latest!)) {
        latest = date;
      }
    }

    for (final crop in crops) {
      visit(crop.plantingDate);
    }

    for (final stock in stocks) {
      for (final transaction in stock.transactions) {
        visit(transaction.performedAt);
      }
    }

    return latest;
  }

  static DateTime _rangeStart(DateTime referenceDate, _AnalyticsRange range) {
    final day = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );

    return switch (range) {
      _AnalyticsRange.week => day.subtract(const Duration(days: 6)),
      _AnalyticsRange.month => DateTime(referenceDate.year, referenceDate.month),
      _AnalyticsRange.year => DateTime(referenceDate.year),
    };
  }

  static bool _isBeforeDay(DateTime value, DateTime compareTo) {
    final day = DateTime(value.year, value.month, value.day);

    return day.isBefore(compareTo);
  }

  static List<DateTime> _trendBuckets(
    DateTime referenceDate,
    _AnalyticsRange range,
  ) {
    final day = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );

    return switch (range) {
      _AnalyticsRange.week => [
          for (var index = 6; index >= 0; index--)
            day.subtract(Duration(days: index)),
        ],
      _AnalyticsRange.month => _monthTrendBuckets(referenceDate),
      _AnalyticsRange.year => [
          for (var index = 5; index >= 0; index--)
            DateTime(referenceDate.year, referenceDate.month - index),
        ],
    };
  }

  static List<DateTime> _monthTrendBuckets(DateTime referenceDate) {
    final buckets = <DateTime>[];
    final referenceDay = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );

    for (var index = 0; index < 5; index++) {
      final bucket = DateTime(referenceDate.year, referenceDate.month, 1 + (index * 7));

      if (!bucket.isAfter(referenceDay)) {
        buckets.add(bucket);
      }
    }

    return buckets;
  }

  static DateTime? _trendKeyFor({
    required DateTime date,
    required _AnalyticsRange range,
    required List<DateTime> buckets,
  }) {
    if (buckets.isEmpty) {
      return null;
    }

    final day = DateTime(date.year, date.month, date.day);

    if (range == _AnalyticsRange.year) {
      final month = DateTime(date.year, date.month);

      return buckets.contains(month) ? month : null;
    }

    if (range == _AnalyticsRange.week) {
      return buckets.contains(day) ? day : null;
    }

    DateTime? selectedBucket;

    for (final bucket in buckets) {
      if (!day.isBefore(bucket)) {
        selectedBucket = bucket;
      }
    }

    return selectedBucket;
  }

  static String _trendBucketLabel(DateTime date, _AnalyticsRange range) {
    if (range == _AnalyticsRange.year) {
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

      return months[date.month - 1];
    }

    return '${date.month}/${date.day}';
  }

  static String _trendLabel(_AnalyticsRange range) {
    return switch (range) {
      _AnalyticsRange.week => 'Daily stock out',
      _AnalyticsRange.month => 'Weekly stock out',
      _AnalyticsRange.year => 'Monthly stock out',
    };
  }
}

class _ChartEntry {
  const _ChartEntry(this.label, this.value);

  final String label;
  final double value;
}

String _formatAnalyticsQuantity(double value) {
  return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}
