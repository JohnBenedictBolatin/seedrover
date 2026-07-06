import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/animated_content.dart';
import '../../../../shared/widgets/content_skeleton.dart';
import '../../data/models/stock_model.dart';
import '../../providers/stock_providers.dart';
import '../widgets/stock_card.dart';
import '../widgets/stock_empty_state.dart';
import '../widgets/stock_filter_bar.dart';

class StockListScreen extends ConsumerWidget {
  const StockListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockInventoryControllerProvider);
    final controller = ref.read(stockInventoryControllerProvider.notifier);

    if (state.isLoading) {
      return const _StockLoadingSkeleton();
    }

    if (state.errorMessage != null) {
      return Center(
        child: Text(state.errorMessage!, style: AppTypography.body),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refreshStocks,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AnimatedTypingText(
            'Stocks',
            style: AppTypography.screenTitle.copyWith(
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          StockFilterBar(
            searchQuery: state.searchQuery,
            selectedCategory: state.selectedCategory,
            selectedFilter: state.selectedFilter,
            selectedSort: state.selectedSort,
            onSearchChanged: controller.updateSearch,
            onCategoryChanged: controller.updateCategory,
            onFilterChanged: controller.updateFilter,
            onSortChanged: controller.updateSort,
            onClear: controller.clearFilters,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (state.filteredStocks.isEmpty)
            StockEmptyState(onClearFilters: controller.clearFilters)
          else
            _StockContent(
              stocks: state.filteredStocks,
              onStockSelected: (stock) {
                context.push(AppRoutes.stockDetailsPath(stock.id));
              },
            ),
        ],
      ),
    );
  }
}

class _StockLoadingSkeleton extends StatelessWidget {
  const _StockLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SkeletonLine(widthFactor: 0.28, height: 30),
        const SizedBox(height: AppSpacing.xl),
        const SkeletonCard(
          children: [
            SkeletonLine(widthFactor: 0.92),
            SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: SkeletonBlock(height: 34)),
                SizedBox(width: AppSpacing.sm),
                Expanded(child: SkeletonBlock(height: 34)),
                SizedBox(width: AppSpacing.sm),
                Expanded(child: SkeletonBlock(height: 34)),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        const SkeletonLine(widthFactor: 0.45, height: 18),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: const [
              SizedBox(width: 280, child: _StockCardSkeleton()),
              SizedBox(width: AppSpacing.md),
              SizedBox(width: 280, child: _StockCardSkeleton()),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SkeletonLine(widthFactor: 0.5, height: 18),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: const [
              SizedBox(width: 280, child: _StockCardSkeleton()),
              SizedBox(width: AppSpacing.md),
              SizedBox(width: 280, child: _StockCardSkeleton()),
            ],
          ),
        ),
      ],
    );
  }
}

class _StockCardSkeleton extends StatelessWidget {
  const _StockCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      children: [
        SkeletonLine(widthFactor: 0.72, height: 18),
        SizedBox(height: AppSpacing.sm),
        SkeletonLine(widthFactor: 0.36),
        SizedBox(height: AppSpacing.md),
        Center(child: SkeletonBlock(height: 94, width: 110)),
        SizedBox(height: AppSpacing.md),
        SkeletonLine(widthFactor: 0.9),
        SizedBox(height: AppSpacing.sm),
        SkeletonLine(widthFactor: 0.75),
        SizedBox(height: AppSpacing.md),
        SkeletonBlock(height: 32),
      ],
    );
  }
}

class _StockContent extends StatelessWidget {
  const _StockContent({
    required this.stocks,
    required this.onStockSelected,
  });

  final List<StockModel> stocks;
  final ValueChanged<StockModel> onStockSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in _groupStocksByCategory(stocks).entries) ...[
          _StockGroup(
            title: '${group.key.label} (${group.value.length})',
            stocks: group.value,
            onStockSelected: onStockSelected,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }

  Map<StockCategory, List<StockModel>> _groupStocksByCategory(
    List<StockModel> stocks,
  ) {
    final sortedStocks = [...stocks]
      ..sort((left, right) {
        final categoryCompare = left.category.label.compareTo(
          right.category.label,
        );

        if (categoryCompare != 0) {
          return categoryCompare;
        }

        return left.name.compareTo(right.name);
      });
    final grouped = <StockCategory, List<StockModel>>{};

    for (final stock in sortedStocks) {
      grouped.putIfAbsent(stock.category, () => []).add(stock);
    }

    return grouped;
  }
}

class _StockGroup extends StatelessWidget {
  const _StockGroup({
    required this.title,
    required this.stocks,
    required this.onStockSelected,
  });

  final String title;
  final List<StockModel> stocks;
  final ValueChanged<StockModel> onStockSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedTypingText(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.cardTitle.copyWith(
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < stocks.length; index++) ...[
                SizedBox(
                  width: 280,
                  child: StockCard(
                    stock: stocks[index],
                    onView: () => onStockSelected(stocks[index]),
                  ),
                ),
                if (index != stocks.length - 1)
                  const SizedBox(width: AppSpacing.md),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
