import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../inventory/data/models/stock_model.dart';
import '../../../inventory/providers/stock_providers.dart';
import '../../../../shared/widgets/content_skeleton.dart';

class DashboardSummaryHero extends ConsumerStatefulWidget {
  const DashboardSummaryHero({
    super.key,
    this.contentAfterHero,
    this.heroImageAsset = 'assets/images/mascots/sales.png',
  });

  final Widget? contentAfterHero;

  @Deprecated('The sales summary now uses a decorative point-of-sale icon.')
  final String? heroImageAsset;

  @override
  ConsumerState<DashboardSummaryHero> createState() =>
      _DashboardSummaryHeroState();
}

class _DashboardSummaryHeroState extends ConsumerState<DashboardSummaryHero> {
  _SalesRange selectedRange = _SalesRange.thisYear;

  @override
  Widget build(BuildContext context) {
    final stockState = ref.watch(stockInventoryControllerProvider);
    if (!stockState.hasSalesSummary) {
      if (stockState.isSalesSummaryLoading) {
        return const SkeletonCard(
          height: 142,
          children: [
            SkeletonLine(widthFactor: .36),
            SizedBox(height: AppSpacing.md),
            SkeletonLine(widthFactor: .6, height: 30),
          ],
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                stockState.salesSummaryError ?? 'Sales totals are unavailable.',
                style: AppTypography.caption,
              ),
            ),
            TextButton(
              onPressed: () => ref
                  .read(stockInventoryControllerProvider.notifier)
                  .refreshSalesSummary(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final summary = stockState.salesSummary;
    final rangeSales = _rangeSales(summary, selectedRange);

    return Column(
      children: [
        _RangeSelector(
          selected: selectedRange,
          onChanged: (range) => setState(() => selectedRange = range),
        ),
        if (stockState.salesSummaryError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Material(
            color: AppColors.secondaryBackground,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      stockState.salesSummaryError!,
                      style: AppTypography.small,
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref
                        .read(stockInventoryControllerProvider.notifier)
                        .refreshSalesSummary(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        _PerformanceHero(
          label: selectedRange.label,
          amount: CurrencyFormatter.php(rangeSales.amount),
          transactions: rangeSales.transactions,
        ),
        if (widget.contentAfterHero != null) ...[
          const SizedBox(height: AppSpacing.md),
          widget.contentAfterHero!,
        ],
      ],
    );
  }

  _RangeSales _rangeSales(
    StockSalesSummaryModel summary,
    _SalesRange range,
  ) {
    if (range == _SalesRange.today) {
      return _RangeSales(
        summary.salesToday,
        summary.salesTransactionsToday,
      );
    }
    if (range == _SalesRange.thisWeek) {
      return _RangeSales(
        summary.salesThisWeek,
        summary.salesTransactionsThisWeek,
      );
    }
    if (range == _SalesRange.thisMonth) {
      return _RangeSales(
        summary.salesThisMonth,
        summary.salesTransactions,
      );
    }
    if (range == _SalesRange.thisYear) {
      return _RangeSales(
        summary.salesThisYear,
        summary.salesTransactionsThisYear,
      );
    }
    return const _RangeSales(0, 0);
  }
}

enum _SalesRange {
  today('Today'),
  thisWeek('This week'),
  thisMonth('This month'),
  thisYear('Yearly');

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
                        ? AppColors.primaryGreen.withValues(alpha: .48)
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
  });

  final String label;
  final String amount;
  final int transactions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 116),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.heroGradientColors.first,
            AppColors.heroGradientColors.last,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: 144,
            child: ExcludeSemantics(
              child: Center(
                child: Transform.rotate(
                  angle: -.16,
                  child: Container(
                    width: 108,
                    height: 108,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: .06),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .18),
                        width: 5,
                      ),
                    ),
                    child: Text(
                      '₱',
                      style: AppTypography.numericValue.copyWith(
                        fontSize: 72,
                        fontWeight: FontWeight.w700,
                        fontVariations: const [FontVariation('wght', 700)],
                        color: Colors.white.withValues(alpha: .28),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
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
                        style: AppTypography.sectionHeading.copyWith(
                          color: AppColors.heroSecondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          amount,
                          maxLines: 1,
                          softWrap: false,
                          style: AppTypography.sectionHeading.copyWith(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            fontVariations: const [FontVariation('wght', 700)],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '$transactions completed transactions',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.heroMutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 86 + AppSpacing.md),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
