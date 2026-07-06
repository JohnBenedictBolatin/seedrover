import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/stock_model.dart';

class StockTransactionTimeline extends StatelessWidget {
  const StockTransactionTimeline({
    required this.transactions,
    super.key,
  });

  final List<StockTransactionModel> transactions;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Text('No stock movements yet.', style: AppTypography.small);
    }

    final sortedTransactions = [...transactions]
      ..sort((left, right) => right.performedAt.compareTo(left.performedAt));

    return Column(
      children: [
        for (final transaction in sortedTransactions) ...[
          _TransactionTile(transaction: transaction),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final StockTransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final color = _transactionColor(transaction.type);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_transactionIcon(transaction.type), color: color, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          transaction.type.label,
                          style: AppTypography.statusBadge.copyWith(
                            color: color,
                          ),
                        ),
                      ),
                      Text(
                        _formatQuantity(transaction.quantity),
                        style: AppTypography.monoSmall.copyWith(color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(transaction.remarks, style: AppTypography.small),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${_formatDate(transaction.performedAt)} '
                    '${_formatTime(transaction.performedAt)}',
                    style: AppTypography.monoCaption,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'By ${transaction.performedBy}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _transactionColor(StockTransactionType type) {
    return switch (type) {
      StockTransactionType.stockIn => AppColors.primaryGreen,
      StockTransactionType.stockOut => AppColors.warning,
      StockTransactionType.adjustment => AppColors.information,
    };
  }

  IconData _transactionIcon(StockTransactionType type) {
    return switch (type) {
      StockTransactionType.stockIn => Icons.add_circle_outline,
      StockTransactionType.stockOut => Icons.remove_circle_outline,
      StockTransactionType.adjustment => Icons.tune,
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
