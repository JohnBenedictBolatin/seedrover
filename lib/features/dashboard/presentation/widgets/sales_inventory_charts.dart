import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/business_calendar.dart';
import '../../../crops/data/models/crop_model.dart';
import '../../../crops/providers/crop_providers.dart';
import '../../../inventory/data/models/stock_model.dart';
import '../../../inventory/providers/stock_providers.dart';
import '../../data/models/dashboard_model.dart';

class SalesInventoryCharts extends ConsumerStatefulWidget {
  const SalesInventoryCharts({required this.rover, super.key});

  final RoverOverviewModel rover;

  @override
  ConsumerState<SalesInventoryCharts> createState() =>
      _SalesInventoryChartsState();
}

class _SalesInventoryChartsState extends ConsumerState<SalesInventoryCharts> {
  _OverviewRange _range = _OverviewRange.yearly;

  @override
  Widget build(BuildContext context) {
    final stockState = ref.watch(stockInventoryControllerProvider);
    final stocks = stockState.stocks;
    final cropState = ref.watch(cropMonitoringControllerProvider);
    final crops = cropState.crops;
    final inventoryUnavailable =
        stockState.errorMessage != null && stocks.isEmpty;
    final cropsUnavailable = cropState.errorMessage != null && crops.isEmpty;
    final trendAsync = ref.watch(stockSalesTrendProvider);
    final overview = _OverviewData.from(
      stocks: stocks,
      crops: crops,
      salesRecords: trendAsync.asData?.value ?? const [],
      range: _range,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Overview',
            style: AppTypography.sectionHeading.copyWith(fontSize: 18)),
        const SizedBox(height: AppSpacing.md),
        _SalesTrendPanel(
          range: _range,
          overview: overview,
          unavailableMessage: trendAsync.hasError
              ? 'Sales trend is unavailable.'
              : stockState.hasSalesSummary && !stockState.isSalesSummaryLoading
                  ? null
                  : !stockState.hasSalesSummary
                      ? (stockState.isSalesSummaryLoading
                          ? null
                          : stockState.salesSummaryError ??
                              'Sales summary is unavailable.')
                      : null,
          isTrendLoading: trendAsync.isLoading,
          onRangeChanged: (range) => setState(() => _range = range),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _SignalCard(
                title: 'In stock',
                value: inventoryUnavailable
                    ? '—'
                    : '${overview.healthyStock}/${overview.stockCount}',
                caption: inventoryUnavailable
                    ? 'inventory data unavailable'
                    : 'items above minimum stock',
                percent: overview.stockHealth,
                color: AppColors.primaryGreen,
                onTap: () => context.go(AppRoutes.stocks),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SignalCard(
                title: 'Harvest ready',
                value: cropsUnavailable ? '—' : '${overview.harvestReadyCrops}',
                caption: cropsUnavailable
                    ? 'crop data unavailable'
                    : '${overview.harvestReadyCrops} ready to harvest',
                percent: overview.cropReadiness,
                color: AppColors.success,
                onTap: () => context.go(AppRoutes.crops),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _MiniStatusCard(
                icon: Icons.smart_toy_outlined,
                title: 'Rover',
                value: widget.rover.status,
                caption: widget.rover.plantingStatus,
                color: _roverColor(widget.rover.status),
                onTap: () => context.go(AppRoutes.rover),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MiniStatusCard(
                icon: Icons.inventory_2_outlined,
                title: 'Low Inventory',
                value: inventoryUnavailable ? '—' : '${overview.watchStock}',
                caption: inventoryUnavailable
                    ? 'data unavailable'
                    : 'needs attention',
                color: overview.watchStock == 0
                    ? AppColors.primaryGreen
                    : AppColors.warning,
                onTap: () => context.go(AppRoutes.stocks),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                'Inventory by Category',
                style: AppTypography.cardTitle.copyWith(fontSize: 15),
              ),
            ),
            InkWell(
              onTap: () => context.go(AppRoutes.stocks),
              child: Text(
                'View All',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _CategoryList(
          categories: overview.categories,
          unavailableMessage: inventoryUnavailable
              ? 'Inventory category data is unavailable.'
              : null,
        ),
      ],
    );
  }
}

enum _OverviewRange {
  weekly('Weekly'),
  monthly('Monthly'),
  quarterly('Quarterly'),
  yearly('Yearly');

  const _OverviewRange(this.label);

  final String label;
}

class _SalesTrendPanel extends StatelessWidget {
  const _SalesTrendPanel({
    required this.range,
    required this.overview,
    required this.unavailableMessage,
    required this.isTrendLoading,
    required this.onRangeChanged,
  });

  final _OverviewRange range;
  final _OverviewData overview;
  final String? unavailableMessage;
  final bool isTrendLoading;
  final ValueChanged<_OverviewRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    return _DarkPanel(
      height: 206,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sales Trend',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _RangeMenu(range: range, onChanged: onRangeChanged),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (isTrendLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (unavailableMessage != null)
            Expanded(
              child: Center(
                child: Text(
                  unavailableMessage!,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Text(
                  '${overview.completedSales}',
                  style: AppTypography.displayHeading.copyWith(
                    color: AppColors.primaryText,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'completed sales in ${range.label.toLowerCase()} view',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _LineGraph(
                entries: overview.salesTrend,
                summary: overview.completedSales == 0
                    ? 'No completed sales recorded in this period.'
                    : 'Completed receipt totals after discounts and completed standalone sales.',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RangeMenu extends StatelessWidget {
  const _RangeMenu({required this.range, required this.onChanged});

  final _OverviewRange range;
  final ValueChanged<_OverviewRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_OverviewRange>(
      onSelected: onChanged,
      color: AppColors.secondaryBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      itemBuilder: (context) => [
        for (final item in _OverviewRange.values)
          PopupMenuItem(
            value: item,
            child: Text(item.label, style: AppTypography.caption),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.primaryGreen.withOpacity(.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              range.label,
              style: AppTypography.numericCaption.copyWith(
                color: AppColors.secondaryText,
                fontSize: 9,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.primaryGreen, size: 15),
          ],
        ),
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.percent,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String value;
  final String caption;
  final double percent;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: _DarkPanel(
          height: 162,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 76,
                child: CustomPaint(
                  painter: _RingPainter(percent: percent, color: color),
                  child: Center(
                    child: Text(
                      value,
                      style: AppTypography.sectionHeading.copyWith(
                        color: AppColors.primaryText,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                caption,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.numericCaption.copyWith(
                  color: AppColors.mutedText,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStatusCard extends StatelessWidget {
  const _MiniStatusCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.caption,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String caption;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: _DarkPanel(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondaryText,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.numericSmall.copyWith(fontSize: 14),
                    ),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.numericCaption.copyWith(fontSize: 8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.categories, this.unavailableMessage});

  final List<_CategoryEntry> categories;
  final String? unavailableMessage;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return _DarkPanel(
        child: Center(
          child: Text(
            unavailableMessage ?? 'No inventory items yet.',
            style: AppTypography.caption,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final category in categories.take(5)) ...[
          _CategoryRow(category: category),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category});

  final _CategoryEntry category;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () => context.go(AppRoutes.stocks),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: _DarkPanel(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: category.color.withOpacity(.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(category.icon, color: category.color, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            category.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primaryText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${_quantity(category.quantity)} items',
                          style: AppTypography.numericSmall.copyWith(
                            fontSize: 13,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            child: LinearProgressIndicator(
                              minHeight: 5,
                              value: (category.percent / 100)
                                  .clamp(0, 1)
                                  .toDouble(),
                              color: category.color,
                              backgroundColor:
                                  AppColors.cardBackground.withOpacity(.72),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${category.percent.round()}%',
                          style: AppTypography.numericCaption.copyWith(
                            color: AppColors.mutedText,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkPanel extends StatelessWidget {
  const _DarkPanel({
    required this.child,
    this.height,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final double? height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LineGraph extends StatelessWidget {
  const _LineGraph({required this.entries, required this.summary});

  final List<_ChartEntry> entries;
  final String summary;

  @override
  Widget build(BuildContext context) {
    if (entries.every((entry) => entry.value == 0)) {
      return Center(
        child: Text(summary, style: AppTypography.caption),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 720),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) {
        return CustomPaint(
          painter: _LinePainter(entries: entries, progress: progress),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final entry in entries)
                  Text(
                    entry.label,
                    style: AppTypography.numericCaption.copyWith(
                      color: AppColors.mutedText,
                      fontSize: 9,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter({required this.entries, required this.progress});

  final List<_ChartEntry> entries;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - 24;
    final maxValue = entries.fold<double>(
      1,
      (value, entry) => math.max(value, entry.value),
    );
    final gridPaint = Paint()
      ..color = AppColors.inactiveBorder.withOpacity(.28)
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = chartHeight * (index / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = <Offset>[];
    for (var index = 0; index < entries.length; index++) {
      final x = entries.length == 1
          ? size.width / 2
          : size.width * (index / (entries.length - 1));
      final y = chartHeight -
          (chartHeight * (entries[index].value / maxValue) * progress);
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 0; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      final controlX = (current.dx + next.dx) / 2;
      path.cubicTo(controlX, current.dy, controlX, next.dy, next.dx, next.dy);
    }
    final fill = Path.from(path)
      ..lineTo(size.width, chartHeight)
      ..lineTo(0, chartHeight)
      ..close();

    canvas.drawPath(
      fill,
      Paint()..color = AppColors.primaryGreen.withOpacity(.11),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primaryGreen
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) {
    return oldDelegate.entries != entries || oldDelegate.progress != progress;
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.percent, required this.color});

  final double percent;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = AppColors.cardBackground.withOpacity(.8);
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(rect.deflate(5), 0, math.pi * 2, false, backgroundPaint);
    canvas.drawArc(
      rect.deflate(5),
      -math.pi / 2,
      math.pi * 2 * (percent.clamp(0, 100) / 100),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.color != color;
  }
}

class _OverviewData {
  const _OverviewData({
    required this.salesTrend,
    required this.categories,
    required this.completedSales,
    required this.stockCount,
    required this.healthyStock,
    required this.watchStock,
    required this.stockHealth,
    required this.harvestReadyCrops,
    required this.cropReadiness,
  });

  final List<_ChartEntry> salesTrend;
  final List<_CategoryEntry> categories;
  final int completedSales;
  final int stockCount;
  final int healthyStock;
  final int watchStock;
  final double stockHealth;
  final int harvestReadyCrops;
  final double cropReadiness;

  factory _OverviewData.from({
    required List<StockModel> stocks,
    required List<CropModel> crops,
    required List<StockSalesTrendRecord> salesRecords,
    required _OverviewRange range,
  }) {
    final now = BusinessCalendar.now();
    final localNow = now.add(BusinessCalendar.timeZoneOffset);
    final buckets = _buckets(localNow, range);
    final salesByBucket = <DateTime, double>{
      for (final bucket in buckets) bucket.date: 0
    };
    final categoryTotals = <StockCategory, int>{};
    final completedSaleIds = <String>{};

    for (final stock in stocks) {
      categoryTotals.update(
        stock.category,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    for (final sale in salesRecords) {
      final saleInstant = sale.date.toUtc();
      if (saleInstant.isAfter(now)) continue;
      final manilaDate = saleInstant.add(BusinessCalendar.timeZoneOffset);
      final day =
          DateTime.utc(manilaDate.year, manilaDate.month, manilaDate.day);
      if (day.isBefore(buckets.first.date)) continue;
      completedSaleIds.add(sale.id);
      final key = _bucketFor(day, buckets);
      salesByBucket[key] = salesByBucket[key]! + sale.total;
    }

    final totalInventoryItems = stocks.length;
    final healthyStock =
        stocks.where((stock) => stock.status == StockStatus.inStock).length;
    final watchStock = stocks
        .where((stock) =>
            stock.status == StockStatus.lowStock ||
            stock.status == StockStatus.criticalStock ||
            stock.status == StockStatus.outOfStock)
        .length;
    final activeCrops = crops.where((crop) => !crop.isCompleted).toList();
    final harvestReady =
        activeCrops.where((crop) => crop.isHarvestReady).length;

    return _OverviewData(
      salesTrend: [
        for (final bucket in buckets)
          _ChartEntry(bucket.label, salesByBucket[bucket.date] ?? 0),
      ],
      categories: [
        for (final entry in categoryTotals.entries)
          _CategoryEntry(
            label: entry.key.label,
            quantity: entry.value.toDouble(),
            percent: totalInventoryItems == 0
                ? 0
                : (entry.value / totalInventoryItems) * 100,
            color: _categoryColor(entry.key),
            icon: _categoryIcon(entry.key),
          ),
      ]..sort((left, right) => right.quantity.compareTo(left.quantity)),
      completedSales: completedSaleIds.length,
      stockCount: stocks.length,
      healthyStock: healthyStock,
      watchStock: watchStock,
      stockHealth: stocks.isEmpty ? 0 : (healthyStock / stocks.length) * 100,
      harvestReadyCrops: harvestReady,
      cropReadiness:
          activeCrops.isEmpty ? 0 : (harvestReady / activeCrops.length) * 100,
    );
  }

  static DateTime _bucketFor(DateTime day, List<_Bucket> buckets) {
    var selected = buckets.first.date;
    for (final bucket in buckets) {
      if (!day.isBefore(bucket.date)) {
        selected = bucket.date;
      }
    }
    return selected;
  }

  static List<_Bucket> _buckets(DateTime now, _OverviewRange range) {
    final today = DateTime.utc(now.year, now.month, now.day);
    switch (range) {
      case _OverviewRange.weekly:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return [
          for (var index = 0; index < 7; index++)
            _Bucket(
              monday.add(Duration(days: index)),
              _weekdayLabel(monday.add(Duration(days: index)).weekday),
            ),
        ];
      case _OverviewRange.monthly:
        return [
          for (var day = 1;
              day <= DateTime.utc(now.year, now.month + 1, 0).day;
              day += 5)
            _Bucket(
              DateTime.utc(now.year, now.month, day),
              '$day',
            ),
        ];
      case _OverviewRange.quarterly:
        final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return [
          for (var index = 0; index < 3; index++)
            _Bucket(
              DateTime.utc(now.year, quarterStartMonth + index),
              _monthLabel(quarterStartMonth + index),
            ),
        ];
      case _OverviewRange.yearly:
        return [
          for (var month = 1; month <= 12; month++)
            _Bucket(
              DateTime.utc(now.year, month),
              _monthLabel(month),
            ),
        ];
    }
  }

  static String _weekdayLabel(int weekday) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[weekday - 1];
  }

  static String _monthLabel(int month) {
    const labels = [
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
    return labels[month - 1];
  }
}

class _Bucket {
  const _Bucket(this.date, this.label);

  final DateTime date;
  final String label;
}

class _CategoryEntry {
  const _CategoryEntry({
    required this.label,
    required this.quantity,
    required this.percent,
    required this.color,
    required this.icon,
  });

  final String label;
  final double quantity;
  final double percent;
  final Color color;
  final IconData icon;
}

class _ChartEntry {
  const _ChartEntry(this.label, this.value);

  final String label;
  final double value;
}

Color _roverColor(String status) {
  final normalized = status.toLowerCase();
  return normalized.contains('online') || normalized.contains('active')
      ? AppColors.primaryGreen
      : AppColors.warning;
}

Color _categoryColor(StockCategory category) {
  return switch (category) {
    StockCategory.leafyVegetables => const Color(0xFF53D11E),
    StockCategory.fruitVegetables => const Color(0xFFFF8A3D),
    StockCategory.legumes => const Color(0xFF27C7A7),
    StockCategory.rootCrops => const Color(0xFFFFB000),
    StockCategory.fruits => const Color(0xFFE95B7A),
    StockCategory.herbs => const Color(0xFF8DFF2A),
    StockCategory.preparedProduce => const Color(0xFF2196F3),
    StockCategory.others => const Color(0xFF9A9A9A),
  };
}

IconData _categoryIcon(StockCategory category) {
  return switch (category) {
    StockCategory.leafyVegetables => Icons.eco_rounded,
    StockCategory.fruitVegetables => Icons.local_florist_rounded,
    StockCategory.legumes => Icons.grass_rounded,
    StockCategory.rootCrops => Icons.yard_rounded,
    StockCategory.fruits => Icons.spa_rounded,
    StockCategory.herbs => Icons.energy_savings_leaf_rounded,
    StockCategory.preparedProduce => Icons.inventory_2_rounded,
    StockCategory.others => Icons.more_horiz_rounded,
  };
}

String _quantity(double value) {
  return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}
