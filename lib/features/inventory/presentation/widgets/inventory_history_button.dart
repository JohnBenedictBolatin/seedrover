import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/history_pagination.dart';
import '../../data/models/inventory_history_model.dart';
import '../../data/repositories/stock_repository.dart';

class InventoryGradientActionButton extends StatelessWidget {
  const InventoryGradientActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 48,
        child: DecoratedBox(
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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: onPressed,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      label,
                      style: AppTypography.small.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class InventoryHistoryButton extends StatelessWidget {
  const InventoryHistoryButton({required this.repository, super.key});

  final StockRepository repository;

  @override
  Widget build(BuildContext context) => InventoryGradientActionButton(
        label: 'View Inventory History',
        icon: Icons.history_rounded,
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _InventoryHistorySheet(repository: repository),
        ),
      );
}

class _InventoryHistorySheet extends StatefulWidget {
  const _InventoryHistorySheet({required this.repository});

  final StockRepository repository;

  @override
  State<_InventoryHistorySheet> createState() => _InventoryHistorySheetState();
}

class _InventoryHistorySheetState extends State<_InventoryHistorySheet> {
  static const _pageSize = 5;

  int _page = 0;
  late Future<InventoryHistoryPage> _records = _loadPage();

  Future<InventoryHistoryPage> _loadPage() =>
      widget.repository.getInventoryHistoryPage(
        pageIndex: _page,
        pageSize: _pageSize,
      );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: FractionallySizedBox(
          heightFactor: .88,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primaryBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inactiveBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.xs,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inventory History',
                              style: AppTypography.sectionHeading,
                            ),
                            Text(
                              'All stock-in and stock-out movements from crops, sales, and manual adjustments.',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close inventory history',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: FutureBuilder<InventoryHistoryPage>(
                    future: _records,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return _HistoryMessage(
                          icon: Icons.cloud_off_outlined,
                          message:
                              'Inventory history could not be loaded. Check your connection and try again.',
                          action: TextButton.icon(
                            onPressed: () => setState(() {
                              _records = _loadPage();
                            }),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        );
                      }
                      final result = snapshot.data!;
                      if (result.records.isEmpty) {
                        return const _HistoryMessage(
                          icon: Icons.history_rounded,
                          message: 'No inventory movements recorded yet.',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.xs,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        itemCount: result.records.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) =>
                            _MovementTile(record: result.records[index]),
                      );
                    },
                  ),
                ),
                FutureBuilder<InventoryHistoryPage>(
                  future: _records,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.hasError) {
                      return const SizedBox(height: AppSpacing.md);
                    }
                    return HistoryPagination(
                      pageIndex: _page,
                      totalRecords: snapshot.data!.total,
                      pageSize: _pageSize,
                      onPageChanged: (page) => setState(() {
                        _page = page;
                        _records = _loadPage();
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.record});

  final InventoryHistoryRecord record;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.inactiveBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.itemName,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(record.stockCode, style: AppTypography.caption),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _formatQuantity(record.quantity),
                  style: AppTypography.numericSmall.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                _MovementField(label: 'Movement', value: record.movementType),
                _MovementField(label: 'Source', value: record.source),
                _MovementField(
                    label: 'Date', value: _formatDate(record.createdAt)),
              ],
            ),
            if (record.remarks.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              _MovementField(label: 'Remarks', value: record.remarks),
            ],
          ],
        ),
      );

  String _formatQuantity(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.month}/${local.day}/${local.year} · $hour:$minute $period';
  }
}

class _MovementField extends StatelessWidget {
  const _MovementField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => RichText(
        text: TextSpan(
          style: AppTypography.caption.copyWith(color: AppColors.secondaryText),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      );
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.primaryGreen, size: 36),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
              if (action != null) action!,
            ],
          ),
        ),
      );
}
