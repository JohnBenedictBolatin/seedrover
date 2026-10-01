import '../widgets/inventory_task_forms.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/permission_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/content_skeleton.dart';
import '../../../../shared/widgets/page_header_actions.dart';
import '../../../authentication/providers/auth_providers.dart';
import '../../data/models/stock_model.dart';
import '../../providers/stock_providers.dart';
import '../widgets/stock_empty_state.dart';
import '../widgets/stock_card.dart';
import '../widgets/stock_filter_bar.dart';
import '../widgets/stock_overview_hero.dart';
import '../../controllers/stock_inventory_state.dart';
import '../../data/repositories/stock_repository.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../../shared/widgets/startup_recovery.dart';
import '../widgets/inventory_history_button.dart';
import '../widgets/inventory_text_scale.dart';

class StockListScreen extends ConsumerWidget {
  const StockListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockInventoryControllerProvider);
    final controller = ref.read(stockInventoryControllerProvider.notifier);
    final profile = ref.watch(authControllerProvider).profile;
    final canManageStocks =
        profile?.hasPermission(PermissionKeys.stocksManage) ?? false;
    final canViewInventoryHistory = profile != null &&
        profile.roleName != 'Farm Planting Manager' &&
        profile.roleName != 'Planting Staff';
    final inStockItems = state.stocks
        .where((stock) => stock.status == StockStatus.inStock)
        .length;
    final needsAttentionItems = state.stocks
        .where((stock) => stock.status != StockStatus.inStock)
        .length;

    if (state.stocks.isEmpty &&
        (state.isLoading || state.errorMessage != null)) {
      return InventoryTextScale(
        child: StartupRecovery(
          loading: const _StockLoadingSkeleton(),
          errorMessage: state.errorMessage,
          onRetry: controller.loadStocks,
          destinations: [
            (label: 'Continue to Dashboard', route: AppRoutes.dashboard),
            if (profile?.hasPermission(PermissionKeys.roverView) == true)
              (label: 'Continue to Rover Control', route: AppRoutes.rover),
          ],
        ),
      );
    }

    return InventoryTextScale(
      child: RefreshIndicator(
        onRefresh: controller.refreshStocks,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
          children: [
            if (state.errorMessage != null) ...[
              MaterialBanner(
                content: Text('Showing saved inventory. ${state.errorMessage}'),
                leading: const Icon(Icons.cloud_off_outlined),
                actions: [
                  TextButton(
                      onPressed: controller.loadStocks,
                      child: const Text('Retry')),
                  TextButton(
                    onPressed: () => controller.clearErrorMessage(),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            AppPageHeader(
              title: 'Inventory',
              actions: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [PageHeaderActions()],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            StockOverviewHero(
              totalItems: state.stocks.length,
              inStockItems: inStockItems,
              needsAttentionItems: needsAttentionItems,
            ),
            if (canManageStocks) ...[
              const SizedBox(height: AppSpacing.sm),
              InventoryGradientActionButton(
                label: 'Add Inventory Item',
                icon: Icons.add_rounded,
                onPressed: () => showInventoryEditor(context, ref, controller),
              ),
            ],
            if (canViewInventoryHistory) ...[
              if (canManageStocks) const SizedBox(height: AppSpacing.sm),
              InventoryHistoryButton(
                repository: ref.read(stockRepositoryProvider),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            StockFilterBar(
              searchQuery: state.searchQuery,
              selectedCategory: state.selectedCategory,
              selectedFilter: state.selectedFilter,
              selectedSort: state.selectedSort,
              onSearchChanged: controller.updateSearch,
              onCategoryChanged: controller.updateCategory,
              onFilterChanged: controller.updateFilter,
              onSortChanged: controller.updateSort,
            ),
            _StockActiveFilters(
              state: state,
              onCategoryRemoved: () => controller.updateCategory(null),
              onStatusRemoved: () =>
                  controller.updateFilter(StockFilterType.all),
              onSortRemoved: () =>
                  controller.updateSort(StockSortType.recentlyUpdated),
              onClear: controller.clearFilters,
            ),
            const SizedBox(height: AppSpacing.md),
            if (state.filteredStocks.isEmpty)
              state.stocks.isEmpty
                  ? const StockEmptyState()
                  : _NoStockResults(onClear: controller.clearFilters)
            else
              _StockContent(
                stocks: state.filteredStocks,
                onStockSelected: (stock) {
                  context.push(AppRoutes.stockDetailsPath(stock.id));
                },
              ),
          ],
        ),
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
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SkeletonLine(widthFactor: 0.34, height: 30),
        const SizedBox(height: AppSpacing.md),
        const SkeletonCard(
          height: 124,
          children: [],
        ),
        const SizedBox(height: AppSpacing.md),
        const SkeletonCard(
          height: 48,
          children: [],
        ),
        const SizedBox(height: AppSpacing.lg),
        const SkeletonLine(widthFactor: 0.5, height: 20),
        const SizedBox(height: AppSpacing.md),
        const SkeletonCard(
          height: 100,
          children: [
            Row(children: [
              SkeletonBlock(width: 44, height: 44),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: SkeletonLine(widthFactor: .9)),
            ]),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const SkeletonCard(
          height: 100,
          children: [
            Row(children: [
              SkeletonBlock(width: 44, height: 44),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: SkeletonLine(widthFactor: .8)),
            ]),
          ],
        ),
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
            category: group.key,
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
    final sortedStocks = [...stocks]..sort((left, right) {
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
    required this.category,
    required this.stocks,
    required this.onStockSelected,
  });

  final StockCategory category;
  final List<StockModel> stocks;
  final ValueChanged<StockModel> onStockSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.sageSurface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                _categoryIcon(category),
                size: 18,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${category.label} (${stocks.length})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cardTitle.copyWith(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Column(
          children: [
            for (var index = 0; index < stocks.length; index++) ...[
              StockCard(
                stock: stocks[index],
                onView: () => onStockSelected(stocks[index]),
              ),
              if (index != stocks.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ],
    );
  }
}

IconData _categoryIcon(StockCategory category) => switch (category) {
      StockCategory.leafyVegetables => Icons.eco_outlined,
      StockCategory.fruitVegetables => Icons.spa_outlined,
      StockCategory.legumes => Icons.grass_outlined,
      StockCategory.rootCrops => Icons.yard_outlined,
      StockCategory.fruits => Icons.restaurant_outlined,
      StockCategory.herbs => Icons.local_florist_outlined,
      StockCategory.preparedProduce => Icons.inventory_2_outlined,
      StockCategory.others => Icons.category_outlined,
    };

class _StockActiveFilters extends StatelessWidget {
  const _StockActiveFilters({
    required this.state,
    required this.onCategoryRemoved,
    required this.onStatusRemoved,
    required this.onSortRemoved,
    required this.onClear,
  });

  final StockInventoryState state;
  final VoidCallback onCategoryRemoved;
  final VoidCallback onStatusRemoved;
  final VoidCallback onSortRemoved;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasCategory = state.selectedCategory != null;
    final hasStatus = state.selectedFilter != StockFilterType.all;
    final hasSort = state.selectedSort != StockSortType.recentlyUpdated;
    if (!hasCategory && !hasStatus && !hasSort) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (hasCategory)
            InputChip(
              label: Text(state.selectedCategory!.label),
              onDeleted: onCategoryRemoved,
              visualDensity: VisualDensity.compact,
            ),
          if (hasStatus)
            InputChip(
              label: Text(state.selectedFilter.label),
              onDeleted: onStatusRemoved,
              visualDensity: VisualDensity.compact,
            ),
          if (hasSort)
            InputChip(
              label: Text('Sort: ${state.selectedSort.label}'),
              onDeleted: onSortRemoved,
              visualDensity: VisualDensity.compact,
            ),
          TextButton(onPressed: onClear, child: const Text('Clear all')),
        ],
      ),
    );
  }
}

class _NoStockResults extends StatelessWidget {
  const _NoStockResults({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.inactiveBorder),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded,
                color: AppColors.primaryGreen, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text('No matching inventory items', style: AppTypography.cardTitle),
            const SizedBox(height: AppSpacing.xs),
            Text('Try changing your search or filters.',
                textAlign: TextAlign.center, style: AppTypography.small),
            TextButton(onPressed: onClear, child: const Text('Clear filters')),
          ],
        ),
      );
}
