import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/animated_content.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/seedrover_mascot.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../authentication/providers/auth_providers.dart';
import '../../controllers/stock_inventory_controller.dart';
import '../../data/models/stock_model.dart';
import '../../providers/stock_providers.dart';
import '../widgets/stock_action_buttons.dart';
import '../widgets/stock_card.dart';
import '../widgets/stock_detail_metric.dart';
import '../widgets/stock_produce_image.dart';
import '../widgets/stock_transaction_timeline.dart';

class StockDetailsScreen extends ConsumerWidget {
  const StockDetailsScreen({
    required this.stockId,
    super.key,
  });

  static const _stockInLocations = [
    'Harvest Bay',
    'Greenhouse Sorting',
    'Field Crate',
    'Market Return',
    'Farm-table Prep',
  ];

  static const _stockOutReasons = [
    'Market Distribution',
    'Farm-table Dining',
    'Kitchen Preparation',
    'Spoilage Removal',
    'Staff Allocation',
  ];

  final String stockId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockInventoryControllerProvider);
    final controller = ref.read(stockInventoryControllerProvider.notifier);
    final profile = ref.watch(authControllerProvider).profile;
    final stock = controller.stockById(stockId);

    ref.listen(stockInventoryControllerProvider, (previous, next) {
      final message = next.successMessage;

      if (message != null && message != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        ref.read(stockInventoryControllerProvider.notifier).clearSuccessMessage();
      }
    });

    if (state.isLoading) {
      return const LoadingIndicator();
    }

    if (stock == null) {
      return Center(
        child: Text('Stock item not found.', style: AppTypography.body),
      );
    }

    final canDelete =
        profile?.isAdministrator == true || profile?.isInventoryManager == true;
    final performedBy = profile?.fullName ?? 'Current User';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _StockDetailsHeader(
          title: 'Details/${stock.displayId.toLowerCase()}',
          onBack: () {
            if (context.canPop()) {
              context.pop();
              return;
            }

            context.go(AppRoutes.stocks);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          backgroundColor: AppColors.secondaryBackground,
          borderColor: AppColors.inactiveBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StockTitle(stock: stock),
              const SizedBox(height: AppSpacing.lg),
              _StockHeroImage(stock: stock),
              const SizedBox(height: AppSpacing.lg),
              _StockMetricGrid(stock: stock),
              const SizedBox(height: AppSpacing.lg),
              StockActionButtons(
                onStockIn: () => _showStockInDialog(
                  context,
                  controller,
                  stock,
                  performedBy,
                ),
                onStockOut: () => _showStockOutDialog(
                  context,
                  controller,
                  stock,
                  performedBy,
                ),
                onAdjust: () => _showAdjustDialog(
                  context,
                  controller,
                  stock,
                  performedBy,
                ),
                onEdit: () => _showEditDialog(
                  context,
                  controller,
                  stock,
                  canDelete: canDelete,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Notes', style: AppTypography.cardTitle),
              const SizedBox(height: AppSpacing.sm),
              Text(stock.notes, style: AppTypography.small),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _SectionCard(
          title: 'Transaction History',
          onHistoryTap: () => _showTransactionHistoryDialog(context, stock),
          child: StockTransactionTimeline(transactions: stock.transactions),
        ),
      ],
    );
  }

  void _showStockInDialog(
    BuildContext context,
    StockInventoryController controller,
    StockModel stock,
    String performedBy,
  ) {
    final quantityController = TextEditingController();
    final remarksController = TextEditingController(text: 'Harvest received.');
    var selectedLocation = _initialDropdownValue(
      options: _stockInLocations,
      currentValue: stock.supplier,
    );

    _showTransactionDialog(
      context: context,
      title: 'Stock In',
      fields: [
        _quantityField(quantityController, 'Quantity'),
        _dropdownField(
          label: 'Stock In Location',
          value: selectedLocation,
          options: _stockInLocations,
          onChanged: (value) => selectedLocation = value,
        ),
        TextField(
          controller: remarksController,
          decoration: const InputDecoration(labelText: 'Remarks'),
        ),
      ],
      onConfirm: () {
        return controller.stockIn(
          stockId: stock.id,
          quantity: _parseQuantity(quantityController.text),
          supplier: selectedLocation,
          remarks: remarksController.text,
          performedBy: performedBy,
        );
      },
    );
  }

  void _showTransactionHistoryDialog(BuildContext context, StockModel stock) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return _StockStyledDialog(
          title: 'Full Transaction History',
          child: SingleChildScrollView(
            child: StockTransactionTimeline(transactions: stock.transactions),
          ),
        );
      },
    );
  }

  void _showStockOutDialog(
    BuildContext context,
    StockInventoryController controller,
    StockModel stock,
    String performedBy,
  ) {
    final quantityController = TextEditingController();
    final remarksController = TextEditingController(text: 'Stock deducted.');
    var selectedReason = _stockOutReasons.first;

    _showTransactionDialog(
      context: context,
      title: 'Stock Out',
      fields: [
        _quantityField(quantityController, 'Quantity'),
        _dropdownField(
          label: 'Reason',
          value: selectedReason,
          options: _stockOutReasons,
          onChanged: (value) => selectedReason = value,
        ),
        TextField(
          controller: remarksController,
          decoration: const InputDecoration(labelText: 'Remarks'),
        ),
      ],
      onConfirm: () {
        return controller.stockOut(
          stockId: stock.id,
          quantity: _parseQuantity(quantityController.text),
          purpose: selectedReason,
          remarks: remarksController.text,
          performedBy: performedBy,
        );
      },
    );
  }

  void _showAdjustDialog(
    BuildContext context,
    StockInventoryController controller,
    StockModel stock,
    String performedBy,
  ) {
    final quantityController = TextEditingController(
      text: _formatQuantity(stock.currentQuantity),
    );
    final reasonController = TextEditingController(text: 'Physical count');
    final remarksController = TextEditingController(text: 'Stock adjusted.');

    _showTransactionDialog(
      context: context,
      title: 'Adjust Stock',
      fields: [
        _quantityField(quantityController, 'New Quantity'),
        TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        TextField(
          controller: remarksController,
          decoration: const InputDecoration(labelText: 'Remarks'),
        ),
      ],
      onConfirm: () {
        return controller.adjustStock(
          stockId: stock.id,
          newQuantity: _parseQuantity(quantityController.text),
          reason: reasonController.text,
          remarks: remarksController.text,
          performedBy: performedBy,
        );
      },
    );
  }

  void _showEditDialog(
    BuildContext parentContext,
    StockInventoryController controller,
    StockModel stock, {
    required bool canDelete,
  }) {
    final nameController = TextEditingController(text: stock.name);
    final unitController = TextEditingController(text: stock.unit);
    final minimumController = TextEditingController(
      text: _formatQuantity(stock.minimumStockLevel),
    );
    final locationController = TextEditingController(text: stock.storageLocation);
    final supplierController = TextEditingController(text: stock.supplier);
    final notesController = TextEditingController(text: stock.notes);
    var category = stock.category;
    String? errorMessage;

    showDialog<void>(
      context: parentContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _StockStyledDialog(
              title: 'Edit Item',
              child: SingleChildScrollView(
                child: _dialogFieldColumn([
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Item Name'),
                  ),
                  DropdownButtonFormField<StockCategory>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      for (final item in StockCategory.values)
                        DropdownMenuItem(value: item, child: Text(item.label)),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => category = value);
                      }
                    },
                  ),
                  TextField(
                    controller: unitController,
                    decoration: const InputDecoration(labelText: 'Unit'),
                  ),
                  _quantityField(minimumController, 'Minimum Stock Level'),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Storage Location',
                    ),
                  ),
                  TextField(
                    controller: supplierController,
                    decoration: const InputDecoration(
                      labelText: 'Harvest Source',
                    ),
                  ),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  if (errorMessage != null)
                    _DialogErrorMessage(message: errorMessage!),
                ]),
              ),
              actions: [
                if (canDelete)
                  _dialogActionButton(
                    label: 'Delete',
                    icon: Icons.delete_outline,
                    color: AppColors.danger,
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Future<void>.microtask(
                        () => _confirmDelete(parentContext, controller, stock),
                      );
                    },
                  ),
                _dialogActionButton(
                  label: 'Cancel',
                  color: AppColors.secondaryText,
                  borderColor: AppColors.inactiveBorder,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                _dialogActionButton(
                  label: 'Save',
                  icon: Icons.check,
                  onPressed: () {
                    final minimum = _parseQuantity(minimumController.text);

                    if (minimum < 0) {
                      setDialogState(() {
                        errorMessage = 'Minimum stock level cannot be negative.';
                      });
                      return;
                    }

                    final updatedStock = stock.copyWith(
                      name: nameController.text,
                      category: category,
                      unit: unitController.text,
                      minimumStockLevel: minimum,
                      storageLocation: locationController.text,
                      supplier: supplierController.text,
                      notes: notesController.text,
                    );

                    _showTransactionDialog(
                      context: dialogContext,
                      title: 'Save Item Changes',
                      message: 'Save changes to ${stock.name}?',
                      fields: const [],
                      onConfirm: () async {
                        await controller.updateStock(updatedStock);
                        Future<void>.microtask(
                          () => Navigator.of(dialogContext).pop(),
                        );
                        return null;
                      },
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    StockInventoryController controller,
    StockModel stock,
  ) {
    _showTransactionDialog(
      context: context,
      title: 'Delete Item',
      message: 'Delete ${stock.name} ${stock.displayId}?',
      fields: const [],
      onConfirm: () async {
        await controller.deleteStock(stock.id);
        context.go(AppRoutes.stocks);
        return null;
      },
    );
  }

  void _showTransactionDialog({
    required BuildContext context,
    required String title,
    required List<Widget> fields,
    required Future<String?> Function() onConfirm,
    String? message,
  }) {
    String? errorMessage;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _StockStyledDialog(
              title: title,
              child: SingleChildScrollView(
                child: _dialogFieldColumn([
                  if (message != null)
                    SeedRoverMascotMessage(
                      message: message,
                      expression: title.contains('Delete')
                          ? SeedRoverMascotExpression.warning
                          : SeedRoverMascotExpression.thinking,
                    ),
                  ...fields,
                  if (errorMessage != null)
                    _DialogErrorMessage(message: errorMessage!),
                ]),
              ),
              actions: [
                _dialogActionButton(
                  label: 'Cancel',
                  color: AppColors.secondaryText,
                  borderColor: AppColors.inactiveBorder,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                _dialogActionButton(
                  label: 'Confirm',
                  icon: Icons.check,
                  onPressed: () async {
                    final validationMessage = await onConfirm();

                    if (validationMessage != null) {
                      setDialogState(() => errorMessage = validationMessage);
                      return;
                    }

                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  TextField _quantityField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }

  DropdownButtonFormField<String> _dropdownField({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      dropdownColor: AppColors.secondaryBackground,
      iconEnabledColor: AppColors.primaryText,
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: (nextValue) {
        if (nextValue != null) {
          onChanged(nextValue);
        }
      },
    );
  }

  String _initialDropdownValue({
    required List<String> options,
    required String currentValue,
  }) {
    return options.contains(currentValue) ? currentValue : options.first;
  }

  Widget _dialogActionButton({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    Color color = AppColors.primaryGreen,
    Color? borderColor,
  }) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: borderColor ?? color),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    );

    if (icon == null) {
      return OutlinedButton(
        style: style,
        onPressed: onPressed,
        child: Text(label),
      );
    }

    return OutlinedButton.icon(
      style: style,
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label),
    );
  }

  Widget _dialogFieldColumn(List<Widget> fields) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < fields.length; index++) ...[
          fields[index],
          if (index != fields.length - 1)
            const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  double _parseQuantity(String value) {
    return double.tryParse(value.trim()) ?? -1;
  }

  String _formatQuantity(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }
}

class _StockDetailsHeader extends StatelessWidget {
  const _StockDetailsHeader({
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GreenGradient(
          child: IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _GreenGradient(
            child: AnimatedTypingText(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.sectionHeading.copyWith(
                color: AppColors.primaryText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StockTitle extends StatelessWidget {
  const _StockTitle({required this.stock});

  final StockModel stock;

  @override
  Widget build(BuildContext context) {
    final statusColor = stockStatusColor(stock.status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedTypingText(
                stock.name,
                style: AppTypography.sectionHeading,
              ),
              const SizedBox(height: AppSpacing.xs),
              AnimatedTypingText(
                stock.category.label,
                style: AppTypography.small,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        StatusBadge(label: stock.status.label, color: statusColor),
      ],
    );
  }
}

class _StockHeroImage extends StatelessWidget {
  const _StockHeroImage({required this.stock});

  final StockModel stock;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: SizedBox(
        height: 168,
        width: double.infinity,
        child: Center(
          child: StockProduceImage(
            itemName: stock.name,
            imageUrl: stock.imageUrl,
            assetPath: stock.imageAssetPath,
            size: 132,
          ),
        ),
      ),
    );
  }
}

class _StockMetricGrid extends StatelessWidget {
  const _StockMetricGrid({required this.stock});

  final StockModel stock;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 3;
        final spacing = AppSpacing.xs * (columns - 1);
        final tileWidth = (constraints.maxWidth - spacing) / columns;

        return Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            StockDetailMetric(
              width: tileWidth,
              label: 'Item ID',
              value: stock.displayId,
              icon: Icons.tag,
            ),
            StockDetailMetric(
              width: tileWidth,
              label: 'Quantity',
              value: '${_formatQuantity(stock.currentQuantity)} ${stock.unit}',
              icon: Icons.inventory_2_outlined,
            ),
            StockDetailMetric(
              width: tileWidth,
              label: 'Min Stock',
              value: '${_formatQuantity(stock.minimumStockLevel)} ${stock.unit}',
              icon: Icons.warning_amber_outlined,
            ),
            StockDetailMetric(
              width: tileWidth,
              label: 'Location',
              value: stock.storageLocation,
              icon: Icons.location_on_outlined,
            ),
            StockDetailMetric(
              width: tileWidth,
              label: 'Source',
              value: stock.supplier,
              icon: Icons.local_shipping_outlined,
            ),
            StockDetailMetric(
              width: tileWidth,
              label: 'Added',
              value: _formatDate(stock.dateAdded),
              icon: Icons.calendar_month_outlined,
            ),
            StockDetailMetric(
              width: tileWidth,
              label: 'Updated',
              value: _formatDate(stock.lastUpdated),
              icon: Icons.update,
            ),
          ],
        );
      },
    );
  }

  String _formatQuantity(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year.toString().substring(2)}';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.onHistoryTap,
  });

  final String title;
  final Widget child;
  final VoidCallback? onHistoryTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.secondaryBackground,
      borderColor: AppColors.inactiveBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTypography.cardTitle)),
              IconButton(
                tooltip: 'View full history',
                onPressed: onHistoryTap,
                icon: const Icon(
                  Icons.history,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _StockStyledDialog extends StatelessWidget {
  const _StockStyledDialog({
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
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
                  child: Text(
                    title,
                    style: AppTypography.cardTitle.copyWith(
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.primaryText),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxContentHeight),
              child: child,
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: actions,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DialogErrorMessage extends StatelessWidget {
  const _DialogErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: AppTypography.small.copyWith(color: AppColors.danger),
    );
  }
}

class _GreenGradient extends StatelessWidget {
  const _GreenGradient({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [
            AppColors.buttonGradientStart,
            AppColors.buttonGradientEnd,
          ],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}
