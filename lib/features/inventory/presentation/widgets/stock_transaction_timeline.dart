import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/stock_model.dart';

class StockTransactionTimeline extends StatelessWidget {
  const StockTransactionTimeline({
    required this.transactions,
    this.unit,
    super.key,
  });

  final List<StockTransactionModel> transactions;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Text('No stock movements yet.', style: AppTypography.small);
    }

    final sortedTransactions = [...transactions]
      ..sort((left, right) => right.performedAt.compareTo(left.performedAt));

    return Column(
      children: [
        for (var index = 0; index < sortedTransactions.length; index++)
          _TransactionTile(
            transaction: sortedTransactions[index],
            unit: unit,
            isLast: index == sortedTransactions.length - 1,
          ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.isLast,
    this.unit,
  });

  final StockTransactionModel transaction;
  final String? unit;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = _transactionColor(transaction.type);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(_transactionIcon(transaction.type),
                color: color, size: 19),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        transaction.type.label,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${_formatQuantity(transaction.quantity)}${unit == null || unit!.isEmpty ? '' : ' $unit'}',
                      style: AppTypography.numericSmall.copyWith(color: color),
                    ),
                  ],
                ),
                if (transaction.remarks.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(transaction.remarks, style: AppTypography.small),
                ],
                if (transaction.batch != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _BatchEstimateTile(
                    batch: transaction.batch!,
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: 2,
                  children: [
                    Text(
                      transaction.dateKnown
                          ? '${_formatDate(transaction.performedAt)} ${_formatTime(transaction.performedAt)}'
                          : 'Date unknown',
                      style: AppTypography.caption,
                    ),
                    if (transaction.performedBy.isNotEmpty)
                      Text('· By ${transaction.performedBy}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.secondaryText,
                          )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _transactionColor(StockTransactionType type) {
    return switch (type) {
      StockTransactionType.stockIn => AppColors.primaryGreen,
      StockTransactionType.stockOut => AppColors.warning,
      StockTransactionType.sale => AppColors.primaryGreen,
      StockTransactionType.adjustment => AppColors.information,
      StockTransactionType.harvest => AppColors.primaryGreen,
      StockTransactionType.opening => AppColors.information,
      StockTransactionType.historical => AppColors.secondaryText,
    };
  }

  IconData _transactionIcon(StockTransactionType type) {
    return switch (type) {
      StockTransactionType.stockIn => Icons.add_circle_outline,
      StockTransactionType.stockOut => Icons.remove_circle_outline,
      StockTransactionType.sale => Icons.point_of_sale_outlined,
      StockTransactionType.adjustment => Icons.tune,
      StockTransactionType.harvest => Icons.agriculture_outlined,
      StockTransactionType.opening => Icons.inventory_2_outlined,
      StockTransactionType.historical => Icons.history_outlined,
    };
  }

  String _formatQuantity(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year.toString().substring(2)}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final marker = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $marker';
  }
}

class _BatchEstimateTile extends StatelessWidget {
  const _BatchEstimateTile({required this.batch});

  final InventoryStockBatch batch;

  @override
  Widget build(BuildContext context) {
    final estimate = !batch.ageKnown
        ? 'Age unknown'
        : batch.estimatedSpoilageOn == null
            ? 'Estimate unavailable'
            : DateFormat.yMMMd().format(batch.estimatedSpoilageOn!);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child:
          Text('Estimated spoilage: $estimate', style: AppTypography.caption),
    );
  }
}
