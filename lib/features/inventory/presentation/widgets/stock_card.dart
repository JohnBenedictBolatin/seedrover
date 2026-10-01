import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
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

    return Material(
      color: AppColors.secondaryBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.smd),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.inactiveBorder),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color: AppColors.sageSurface,
                  child: StockProduceImage(
                    itemName: stock.name,
                    imageUrl: stock.imageUrl,
                    assetPath: stock.imageAssetPath,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stock.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle,
                    ),
                    Text(
                      stock.displayId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.numericCaption.copyWith(
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    Text(
                      '${stock.category.label} · ${stock.storageLocation}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${_formatQuantity(stock.currentQuantity)} ${stock.unit} available',
                          style: AppTypography.numericSmall.copyWith(
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        _StockStatusBadge(
                          label: stock.status.label,
                          color: statusColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _formatQuantity(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}

class _StockStatusBadge extends StatelessWidget {
  const _StockStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

Color stockStatusColor(StockStatus status) => switch (status) {
      StockStatus.inStock => AppColors.primaryGreen,
      StockStatus.lowStock => AppColors.warning,
      StockStatus.criticalStock => AppColors.danger,
      StockStatus.outOfStock => AppColors.mutedText,
    };
