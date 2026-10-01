import '../widgets/inventory_task_forms.dart';
import '../../../../shared/widgets/action_confirmation.dart';
import '../../../../shared/widgets/task_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/permission_keys.dart';
import '../../../../core/constants/workspace_action.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_indicator.dart';
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

    ref.listen(stockInventoryControllerProvider, (previous, next) {
      final message = next.successMessage;

      if (message != null && message != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        ref
            .read(stockInventoryControllerProvider.notifier)
            .clearSuccessMessage();
      }
    });

    if (state.isLoading && stock == null) {
      return const InventoryTextScale(child: LoadingIndicator());
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('This task is no longer available for your account.'),
          ));
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
                      onAdjust: canManage
                          ? () => _showAdjustDialog(
                              context, controller, stock, performedBy)
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
                    StockHistorySection(stock: stock),
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

  void _showAdjustDialog(
          BuildContext context,
          StockInventoryController controller,
          StockModel stock,
          String performedBy) =>
      showInventoryTransaction(
          context, ref, controller, stock, InventoryTask.adjust);

  void _showEditDialog(BuildContext context,
          StockInventoryController controller, StockModel stock,
          {required bool canEditPricing}) =>
      showInventoryEditor(context, ref, controller,
          stock: stock, canEditPricing: canEditPricing);

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
    this.onAdjust,
    this.onEdit,
    super.key,
  });

  final StockModel stock;
  final VoidCallback? onRecordSale;
  final VoidCallback? onDelete;
  final VoidCallback? onReceive;
  final VoidCallback? onIssue;
  final VoidCallback? onAdjust;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: AppColors.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
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
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete item',
                  onPressed: onDelete,
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size(48, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      side: BorderSide(color: AppColors.danger),
                    ),
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
            backgroundColor: AppColors.secondaryBackground,
            borderColor: AppColors.inactiveBorder,
            padding: const EdgeInsets.all(AppSpacing.md),
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
                          label: 'Available quantity',
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
                          label: 'Storage location',
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
                    if (onReceive != null &&
                        onIssue != null &&
                        onAdjust != null &&
                        onEdit != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      InventoryActionSection(
                        onReceive: onReceive!,
                        onIssue: onIssue!,
                        onAdjust: onAdjust!,
                        onEdit: onEdit!,
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
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
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
    required this.onAdjust,
    required this.onEdit,
    super.key,
  });

  final VoidCallback onReceive;
  final VoidCallback onIssue;
  final VoidCallback onAdjust;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Manage item', style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _ManageActionButton(
                  label: 'Adjust quantity',
                  icon: Icons.tune_rounded,
                  onTap: onAdjust,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ManageActionButton(
                  label: 'Edit item',
                  icon: Icons.edit_outlined,
                  onTap: onEdit,
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
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryGreen,
            side: BorderSide(color: AppColors.primaryGreen),
            backgroundColor: Colors.transparent,
            minimumSize: const Size.fromHeight(64),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(height: AppSpacing.xs),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class StockHistorySection extends StatelessWidget {
  const StockHistorySection({required this.stock, super.key});

  final StockModel stock;

  @override
  Widget build(BuildContext context) => AppCard(
        backgroundColor: AppColors.cardBackground,
        borderColor: AppColors.inactiveBorder,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Transaction history',
                      style: AppTypography.cardTitle),
                ),
                Text('${stock.transactions.length}',
                    style: AppTypography.numericCaption),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            StockTransactionTimeline(
              transactions: stock.transactions,
              unit: stock.unit,
            ),
          ],
        ),
      );
}

String _formatDate(DateTime date) =>
    '${date.month}/${date.day}/${date.year.toString().substring(2)}';

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
