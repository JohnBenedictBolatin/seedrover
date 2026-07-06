import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/animated_content.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/models/stock_model.dart';
import 'stock_produce_image.dart';

class StockCard extends StatelessWidget {
  const StockCard({
    required this.stock,
    required this.onView,
    super.key,
  });

  final StockModel stock;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final statusColor = stockStatusColor(stock.status);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border.all(color: AppColors.inactiveBorder),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AnimatedTypingText(
                    stock.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cardTitle.copyWith(
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                StatusBadge(label: stock.status.label, color: statusColor),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AnimatedTypingText(
              stock.id.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.monoCaption.copyWith(
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: StockProduceImage(itemName: stock.name, size: 78),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _StockMetaRow(label: 'Category', value: stock.category.label),
            const SizedBox(height: AppSpacing.xs),
            _StockMetaRow(
              label: 'Quantity',
              value: '${_formatQuantity(stock.currentQuantity)} ${stock.unit}',
              isTechnical: true,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onView,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.cardBackground,
                  foregroundColor: AppColors.primaryGreen,
                  minimumSize: const Size.fromHeight(32),
                  side: const BorderSide(color: AppColors.primaryGreen),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                child: Text(
                  'View',
                  style: AppTypography.statusBadge.copyWith(
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatQuantity(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }
}

class _StockMetaRow extends StatelessWidget {
  const _StockMetaRow({
    required this.label,
    required this.value,
    this.isTechnical = false,
  });

  final String label;
  final String value;
  final bool isTechnical;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AnimatedTypingText(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: AnimatedMetricText(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: (isTechnical ? AppTypography.monoCaption : AppTypography.caption)
                .copyWith(color: AppColors.primaryText),
          ),
        ),
      ],
    );
  }
}

Color stockStatusColor(StockStatus status) {
  return switch (status) {
    StockStatus.inStock => AppColors.primaryGreen,
    StockStatus.lowStock => AppColors.warning,
    StockStatus.criticalStock => AppColors.danger,
    StockStatus.outOfStock => AppColors.mutedText,
  };
}
