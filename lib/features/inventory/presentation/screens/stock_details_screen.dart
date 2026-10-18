import '../widgets/inventory_task_forms.dart';
import '../../../../shared/widgets/action_confirmation.dart';
import '../../../../shared/widgets/task_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;

import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/permission_keys.dart';
import '../../../../core/constants/workspace_action.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/action_result_dialog.dart';
import '../../../../shared/widgets/history_pagination.dart';
import '../../../../shared/widgets/content_skeleton.dart';
import '../../../../shared/widgets/initial_loading_skeleton.dart';
import '../../../authentication/providers/auth_providers.dart';
import '../../controllers/stock_inventory_controller.dart';
import '../../data/models/stock_model.dart';
import '../../providers/stock_providers.dart';
import '../widgets/stock_card.dart';
import '../widgets/stock_produce_image.dart';
import '../widgets/stock_transaction_timeline.dart';
import '../widgets/inventory_text_scale.dart';

class StockDetailsScreen extends ConsumerStatefulWidget {
  const StockDetailsScreen({
    required this.stockId,
    this.initialAction,
    super.key,
  });

  final String stockId;
  final WorkspaceAction? initialAction;

  @override
  ConsumerState<StockDetailsScreen> createState() => _StockDetailsScreenState();
}

class _StockDetailsScreenState extends ConsumerState<StockDetailsScreen>
    with SingleTickerProviderStateMixin {
  bool _openedInitialAction = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockInventoryControllerProvider);
    final controller = ref.read(stockInventoryControllerProvider.notifier);
    final profile = ref.watch(authControllerProvider).profile;
    final stock = controller.stockById(widget.stockId);

    if (state.isLoading && stock == null) {
      return const InventoryTextScale(
        child: InitialLoadingSkeleton(
          skeleton: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: SkeletonCard(
              height: 260,
              children: [
                SkeletonLine(widthFactor: .54, height: 24),
                SizedBox(height: AppSpacing.lg),
                SkeletonBlock(height: 100),
                SizedBox(height: AppSpacing.md),
                SkeletonLine(widthFactor: .82),
                SizedBox(height: AppSpacing.sm),
                SkeletonLine(widthFactor: .6),
              ],
            ),
          ),
          label: 'Loading item details…',
        ),
      );
    }

    if (stock == null && state.errorMessage != null) {
      return InventoryTextScale(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined),
                const SizedBox(height: AppSpacing.sm),
                Text('Item details could not be loaded.',
                    style: AppTypography.body),
                TextButton.icon(
                  onPressed: controller.loadStocks,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (stock == null) {
      return InventoryTextScale(
        child: Center(
          child: Text('Inventory item not found.', style: AppTypography.body),
        ),
      );
    }

    if (!_openedInitialAction && widget.initialAction != null) {
      _openedInitialAction = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final action = widget.initialAction!;
        if (!(profile?.hasPermission(action.permission) ?? false)) {
          showActionResult(context,
              message: 'This task is no longer available for your account.',
              success: false);
          return;
        }
        switch (action) {
          case WorkspaceAction.recordSale:
            _showStockOutDialog(context, controller, stock,
                profile?.fullName ?? 'Current User');
            break;
          case WorkspaceAction.receiveStock:
            _showStockInDialog(context, controller, stock,
                profile?.fullName ?? 'Current User');
            break;
          case WorkspaceAction.issueStock:
            _showStockOutDialog(
              context,
              controller,
              stock,
              profile?.fullName ?? 'Current User',
              initialReason: 'Staff Allocation',
              allowSale:
                  profile?.hasPermission(PermissionKeys.stocksSalesRecord) ??
                      false,
            );
            break;
          default:
            break;
        }
      });
    }

    final canDelete = profile?.isAdministrator ?? false;
    final canCancelSales =
        profile?.isAdministrator == true || profile?.isInventoryManager == true;
    final canManage =
        profile?.hasPermission(PermissionKeys.stocksManage) ?? false;
    final canEditPricing = profile?.isAdministrator == true ||
        profile?.isInventoryManager == true ||
        (profile?.hasPermission(PermissionKeys.stocksPricingManage) ?? false) ||
        (profile?.hasPermission(PermissionKeys.stocksManage) ?? false);
    final performedBy = profile?.fullName ?? 'Current User';

    return InventoryTextScale(
      child: Column(
        children: [
          StockDetailsHeader(
            onBack: () {
              if (context.canPop()) {
                context.pop();
                return;
              }
              context.go(AppRoutes.stocks);
            },
          ),
          StockDetailsTabBar(controller: _tabController),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                InventoryTabPage(
                  children: [
                    StockOverviewCard(
                      stock: stock,
                      onRecordSale: profile?.hasPermission(
                                  PermissionKeys.stocksSalesRecord) ==
                              true
                          ? () => _showStockOutDialog(
                              context, controller, stock, performedBy)
                          : null,
                      onDelete: canManage && canDelete
                          ? () => _confirmDelete(context, controller, stock)
                          : null,
                      onReceive: canManage
                          ? () => _showStockInDialog(
                              context, controller, stock, performedBy)
                          : null,
                      onIssue: canManage
                          ? () => _showStockOutDialog(
                                context,
                                controller,
                                stock,
                                performedBy,
                                initialReason: 'Staff Allocation',
                              )
                          : null,
                      onEdit: canManage
                          ? () => _showEditDialog(
                                context,
                                controller,
                                stock,
                                canEditPricing: canEditPricing,
                              )
                          : null,
                    ),
                  ],
                ),
                InventoryTabPage(
                  children: [
                    StockHistorySection(
                      stock: stock,
                      canCancelSales: canCancelSales,
                      onCancelSale: canCancelSales
                          ? (sale) => _confirmCancelSale(
                              context, controller, stock, sale)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStockInDialog(
          BuildContext context,
          StockInventoryController controller,
          StockModel stock,
          String performedBy) =>
      showInventoryTransaction(
          context, ref, controller, stock, InventoryTask.receive);

  void _showStockOutDialog(
          BuildContext context,
          StockInventoryController controller,
          StockModel stock,
          String performedBy,
          {String? initialReason,
          bool allowSale = true}) =>
      showInventoryTransaction(
          context,
          ref,
          controller,
          stock,
          initialReason != null || !allowSale
              ? InventoryTask.issue
              : InventoryTask.sale);

  void _showEditDialog(BuildContext context,
          StockInventoryController controller, StockModel stock,
          {required bool canEditPricing}) =>
      showInventoryEditor(context, ref, controller,
          stock: stock, canEditPricing: canEditPricing);

  Future<void> _confirmCancelSale(
    BuildContext context,
    StockInventoryController controller,
    StockModel stock,
    SalesTransactionModel sale,
  ) async {
    final unresolved = await controller.pendingWriteFor(stock.id);
    if (!context.mounted) return;
    if (unresolved != null) {
      await reconcileInventoryWrite(context, controller, stock.id);
      return;
    }
    final reason = TextEditingController(text: 'Incorrect sales transaction.');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this sale?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'The sold quantity will be returned to its original stock batch.'),
          const SizedBox(height: AppSpacing.sm),
          TextField(
              controller: reason,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Reason')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep sale')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cancel sale')),
        ],
      ),
    );
    final reasonText = reason.text.trim();
    reason.dispose();
    if (confirmed != true || !context.mounted) return;
    if (reasonText.isEmpty) {
      await showActionResult(context,
          message: 'Enter a reason before cancelling this sale.',
          success: false);
      return;
    }
    final submissionId = _newVoidSubmissionId();
    final error = await controller.voidSale(
      stockId: stock.id,
      saleId: sale.id,
      reason: reasonText,
      submissionId: submissionId,
    );
    if (!context.mounted) return;
    await showActionResult(
      context,
      message: error ?? 'Sale cancelled and inventory restored.',
      success: error == null,
    );
  }

  Future<void> _confirmDelete(BuildContext context,
      StockInventoryController controller, StockModel stock) async {
    final pending = await controller.pendingWriteFor(stock.id);
    if (!context.mounted) return;
    if (pending != null) {
      final resolution =
          await reconcileInventoryWrite(context, controller, stock.id);
      if (!context.mounted) return;
      if (resolution.status == ActionStatus.verifiedAbsent && context.mounted) {
        return _confirmDelete(context, controller, stock);
      }
      if (resolution.canClose &&
          context.mounted &&
          controller.stockById(stock.id) == null) {
        context.go(AppRoutes.stocks);
      }
      if (pending.status == ActionStatus.uncertain) return;
    }
    if (!context.mounted) return;
    final result = await showActionConfirmation(context,
        title: 'Delete item?',
        message:
            'Delete ${stock.name} (${stock.displayId})? This removes the inventory item if its existing records allow deletion. This cannot be undone.',
        actionLabel: 'Delete item',
        destructive: true,
        onConfirm: () async {
          if (ref.read(authControllerProvider).profile?.isAdministrator !=
              true) {
            return const ActionOutcome.failure(
                'You no longer have access to delete this item.');
          }
          final ok = await controller.deleteStock(stock.id);
          return ok
              ? const ActionOutcome.success()
              : ActionOutcome.failure(
                  ref.read(stockInventoryControllerProvider).errorMessage ??
                      'Unable to delete this item.');
        },
        onReconcile: () =>
            reconcileInventoryWrite(context, controller, stock.id));
    if (result?.canClose == true && context.mounted) {
      context.go(AppRoutes.stocks);
    }
  }
}

class StockDetailsHeader extends StatelessWidget {
  const StockDetailsHeader({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: AppColors.primaryGreen,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 52),
              ),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Text(
                'Inventory Details',
                textAlign: TextAlign.center,
                style: AppTypography.cardTitle.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      );
}

class StockDetailsTabBar extends StatelessWidget {
  const StockDetailsTabBar({required this.controller, super.key});

  final TabController controller;

  @override
  Widget build(BuildContext context) => TabBar(
        controller: controller,
        isScrollable: false,
        tabAlignment: TabAlignment.fill,
        labelColor: AppColors.primaryGreen,
        unselectedLabelColor: AppColors.secondaryText,
        indicatorColor: AppColors.primaryGreen,
        labelStyle: AppTypography.small.copyWith(fontWeight: FontWeight.w700),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'History'),
        ],
      );
}

class InventoryTabPage extends StatelessWidget {
  const InventoryTabPage({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const SizedBox(height: AppSpacing.md),
          ],
        ],
      );
}

class StockOverviewCard extends StatelessWidget {
  const StockOverviewCard({
    required this.stock,
    this.onRecordSale,
    this.onDelete,
    this.onReceive,
    this.onIssue,
    this.onEdit,
    super.key,
  });

  final StockModel stock;
  final VoidCallback? onRecordSale;
  final VoidCallback? onDelete;
  final VoidCallback? onReceive;
  final VoidCallback? onIssue;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stock.name, style: AppTypography.cardTitle),
                    Text(
                      '${stock.category.label} · ${stock.displayId}',
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      stock.status.label,
                      style: AppTypography.caption.copyWith(
                        color: stockStatusColor(stock.status),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Edit item',
                  onPressed: onEdit,
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete item',
                  onPressed: onDelete,
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: StockProduceImage(
              itemName: stock.name,
              imageUrl: stock.imageUrl,
              assetPath: stock.imageAssetPath,
              size: 112,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            backgroundColor: Colors.transparent,
            padding: EdgeInsets.zero,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gap = AppSpacing.sm;
                final tileWidth = (constraints.maxWidth - gap) / 2;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        _InventoryOverviewFact(
                          width: tileWidth,
                          label: 'Quantity',
                          value:
                              '${quantityText(stock.currentQuantity)} ${stock.unit}',
                          icon: Icons.inventory_outlined,
                        ),
                        _InventoryOverviewFact(
                          width: tileWidth,
                          label: 'Price',
                          value:
                              CurrencyFormatter.phpOrUnset(stock.sellingPrice),
                          icon: Icons.sell_outlined,
                        ),
                        _InventoryOverviewFact(
                          width: tileWidth,
                          label: 'Location',
                          value: stock.storageLocation.trim().isEmpty
                              ? 'Not recorded'
                              : stock.storageLocation,
                          icon: Icons.location_on_outlined,
                        ),
                        _InventoryOverviewFact(
                          width: tileWidth,
                          label: 'Last updated',
                          value: _formatDate(stock.lastUpdated),
                          icon: Icons.update_rounded,
                        ),
                      ],
                    ),
                    if (onRecordSale != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      InventoryPrimaryActionTile(
                        label: 'Record sale',
                        icon: Icons.point_of_sale_outlined,
                        color: AppColors.primaryGreen,
                        onTap: onRecordSale!,
                      ),
                    ],
                    if (onReceive != null && onIssue != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      InventoryActionSection(
                        onReceive: onReceive!,
                        onIssue: onIssue!,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      );
}

class _InventoryOverviewFact extends StatelessWidget {
  const _InventoryOverviewFact({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primaryGreen, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: Text(label, style: AppTypography.caption)),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: AppTypography.small.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
}

class InventoryActionSection extends StatelessWidget {
  const InventoryActionSection({
    required this.onReceive,
    required this.onIssue,
    super.key,
  });

  final VoidCallback onReceive;
  final VoidCallback onIssue;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _ManageActionButton(
                  label: 'Receive stock',
                  icon: Icons.add_box_outlined,
                  onTap: onReceive,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ManageActionButton(
                  label: 'Issue stock',
                  icon: Icons.indeterminate_check_box_outlined,
                  onTap: onIssue,
                ),
              ),
            ],
          ),
        ],
      );
}

class _ManageActionButton extends StatelessWidget {
  const _ManageActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryGreen,
            backgroundColor: Colors.transparent,
            side: BorderSide(color: AppColors.primaryGreen),
            minimumSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
          ),
          icon: Icon(icon, size: 18),
          label: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      );
}

class StockHistorySection extends StatefulWidget {
  const StockHistorySection({
    required this.stock,
    this.canCancelSales = false,
    this.onCancelSale,
    super.key,
  });

  final StockModel stock;
  final bool canCancelSales;
  final ValueChanged<SalesTransactionModel>? onCancelSale;

  @override
  State<StockHistorySection> createState() => _StockHistorySectionState();
}

class _StockHistorySectionState extends State<StockHistorySection> {
  static const _pageSize = 5;
  int _pageIndex = 0;
  int _salePageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final transactions = [...widget.stock.transactions]
      ..sort((left, right) => right.performedAt.compareTo(left.performedAt));
    final pageCount =
        transactions.isEmpty ? 1 : (transactions.length / _pageSize).ceil();
    final pageIndex = _pageIndex.clamp(0, pageCount - 1);
    final visibleTransactions = transactions
        .skip(pageIndex * _pageSize)
        .take(_pageSize)
        .toList(growable: false);
    final sales = [...widget.stock.sales]
      ..sort((left, right) => right.saleDate.compareTo(left.saleDate));
    final visibleSales = sales
        .skip(_salePageIndex * _pageSize)
        .take(_pageSize)
        .toList(growable: false);

    return AppCard(
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text('Transaction history', style: AppTypography.cardTitle),
              ),
              Text('${transactions.length}',
                  style: AppTypography.numericCaption),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          StockTransactionTimeline(
            transactions: visibleTransactions,
            unit: widget.stock.unit,
          ),
          if (transactions.length > _pageSize)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: HistoryPagination(
                pageIndex: pageIndex,
                totalRecords: transactions.length,
                pageSize: _pageSize,
                onPageChanged: (nextPage) => setState(() {
                  _pageIndex = nextPage;
                }),
              ),
            ),
          if (sales.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(children: [
              Expanded(child: Text('Sales', style: AppTypography.cardTitle)),
              Text('${sales.length}', style: AppTypography.numericCaption),
            ]),
            for (final sale in visibleSales)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    '${sale.quantitySold.toStringAsFixed(2)} kg · ${sale.customerName ?? 'Customer'}'),
                subtitle: Text(
                    '${DateTimeFormatter.formatDate(sale.saleDate)} · PHP ${sale.totalAmount.toStringAsFixed(2)} · ${sale.status.label}'),
                trailing: widget.canCancelSales &&
                        widget.onCancelSale != null &&
                        sale.status == SalesTransactionStatus.completed
                    ? TextButton(
                        onPressed: () => widget.onCancelSale!(sale),
                        child: const Text('Cancel'))
                    : null,
              ),
            if (sales.length > _pageSize)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: HistoryPagination(
                  pageIndex: _salePageIndex,
                  totalRecords: sales.length,
                  pageSize: _pageSize,
                  onPageChanged: (nextPage) =>
                      setState(() => _salePageIndex = nextPage),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.month}/${date.day}/${date.year.toString().substring(2)}';

String _newVoidSubmissionId() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class InventoryPrimaryActionTile extends StatelessWidget {
  const InventoryPrimaryActionTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
        ),
      );
}
