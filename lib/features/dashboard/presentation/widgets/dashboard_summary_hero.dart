import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../inventory/data/models/stock_model.dart';
import '../../../inventory/providers/stock_providers.dart';

class DashboardSummaryHero extends ConsumerStatefulWidget {
  const DashboardSummaryHero({
    super.key,
    this.contentAfterHero,
    this.heroImageAsset = 'assets/images/sales_today.png',
  });

  final Widget? contentAfterHero;
  final String? heroImageAsset;

  @override
  ConsumerState<DashboardSummaryHero> createState() =>
      _DashboardSummaryHeroState();
}

class _DashboardSummaryHeroState extends ConsumerState<DashboardSummaryHero> {
  _SalesRange selectedRange = _SalesRange.today;

  @override
  Widget build(BuildContext context) {
    final stockState = ref.watch(stockInventoryControllerProvider);
    final summary = stockState.salesSummary;
    final rangeSales = _rangeSales(stockState.stocks, summary, selectedRange);

    return Column(
      children: [
        _RangeSelector(
          selected: selectedRange,
          onChanged: (range) => setState(() => selectedRange = range),
        ),
        const SizedBox(height: AppSpacing.sm),
        _PerformanceHero(
          label: selectedRange.label,
          amount: CurrencyFormatter.php(rangeSales.amount),
          transactions: rangeSales.transactions,
          imageAsset: widget.heroImageAsset,
        ),
        if (widget.contentAfterHero != null) ...[
          const SizedBox(height: AppSpacing.md),
          widget.contentAfterHero!,
        ],
      ],
    );
  }

  _RangeSales _rangeSales(
    List<StockModel> stocks,
    StockSalesSummaryModel summary,
    _SalesRange range,
  ) {
    if (range == _SalesRange.today) {
      return _RangeSales(summary.salesToday, _countToday(stocks));
    }
    if (range == _SalesRange.thisMonth) {
      return _RangeSales(summary.salesThisMonth, summary.salesTransactions);
    }

    final now = DateTime.now();
    final start = range == _SalesRange.thisWeek
        ? DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1))
        : DateTime(now.year);
    var amount = 0.0;
    var count = 0;
    for (final stock in stocks) {
      for (final sale in stock.sales) {
        if (sale.status == SalesTransactionStatus.completed &&
            !sale.saleDate.isBefore(start)) {
          amount += sale.totalAmount;
          count++;
        }
      }
    }
    return _RangeSales(amount, count);
  }

  int _countToday(List<StockModel> stocks) {
    final now = DateTime.now();
    return stocks.expand((stock) => stock.sales).where((sale) {
      final date = sale.saleDate;
      return sale.status == SalesTransactionStatus.completed &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).length;
  }
}

enum _SalesRange {
  today('Today'),
  thisWeek('This week'),
  thisMonth('This month'),
  thisYear('This year');

  const _SalesRange(this.label);
  final String label;
}

class _RangeSales {
  const _RangeSales(this.amount, this.transactions);
  final double amount;
  final int transactions;
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onChanged});

  final _SalesRange selected;
  final ValueChanged<_SalesRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < _SalesRange.values.length; index++) ...[
          if (index > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: InkWell(
              onTap: () => onChanged(_SalesRange.values[index]),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == _SalesRange.values[index]
                      ? AppColors.cardBackground
                      : AppColors.secondaryBackground,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: selected == _SalesRange.values[index]
                        ? AppColors.primaryGreen.withOpacity(.48)
                        : AppColors.inactiveBorder,
                  ),
                ),
                child: Text(
                  _SalesRange.values[index].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: selected == _SalesRange.values[index]
                        ? AppColors.primaryText
                        : AppColors.mutedText,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PerformanceHero extends StatelessWidget {
  const _PerformanceHero({
    required this.label,
    required this.amount,
    required this.transactions,
    required this.imageAsset,
  });

  final String label;
  final String amount;
  final int transactions;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 138,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: RadialGradient(
          center: Alignment.bottomCenter,
          radius: 1.25,
          colors: AppColors.heroGradientColors,
        ),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(.34)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _StarFieldPainter())),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sales - $label',
                        style: AppTypography.small.copyWith(
                          color: AppColors.heroSecondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        amount,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.displayHeading.copyWith(
                          color: Colors.white,
                          fontSize: 26,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$transactions completed transactions',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.monoCaption.copyWith(
                          color: AppColors.heroMutedText,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _HeroImage(asset: imageAsset),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.asset});

  final String? asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      alignment: Alignment.center,
      child: asset == null || asset!.isEmpty
          ? _HeroImageFallback()
          : Image.asset(
              asset!,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _HeroImageFallback(),
            ),
    );
  }
}

class _HeroImageFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.image_outlined,
      color: AppColors.primaryGreen.withOpacity(.72),
      size: 28,
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const stars = <Offset>[
      Offset(.06, .17),
      Offset(.14, .32),
      Offset(.24, .14),
      Offset(.32, .52),
      Offset(.43, .22),
      Offset(.55, .12),
      Offset(.64, .38),
      Offset(.73, .19),
      Offset(.84, .46),
      Offset(.93, .24),
      Offset(.19, .72),
      Offset(.49, .68),
      Offset(.77, .74),
    ];
    final paint = Paint()..color = AppColors.accentGreen.withOpacity(.42);
    for (var index = 0; index < stars.length; index++) {
      final star = stars[index];
      canvas.drawCircle(
        Offset(star.dx * size.width, star.dy * size.height),
        index.isEven ? 1.1 : .7,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
