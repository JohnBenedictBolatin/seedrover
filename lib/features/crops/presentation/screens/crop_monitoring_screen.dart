import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/content_skeleton.dart';
import '../../data/models/crop_model.dart';
import '../../controllers/crop_monitoring_state.dart';
import '../../providers/crop_providers.dart';
import '../widgets/crop_empty_state.dart';
import '../widgets/crop_filter_bar.dart';
import '../widgets/crop_overview_hero.dart';
import '../widgets/crop_screen_header.dart';
import '../widgets/planted_crop_group.dart';

class CropMonitoringScreen extends ConsumerWidget {
  const CropMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cropMonitoringControllerProvider);
    final controller = ref.read(cropMonitoringControllerProvider.notifier);
    final today = DateTime.now();

    if (state.isLoading) {
      return const _CropLoadingSkeleton();
    }

    return RefreshIndicator(
      onRefresh: controller.refreshCrops,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const CropScreenHeader(),
          const SizedBox(height: AppSpacing.lg),
          CropOverviewHero(
            activeCrops: state.activeCrops,
            needsAttention: state.crops
                .where((crop) =>
                    crop.status == CropStatus.needsWater ||
                    crop.status == CropStatus.needsFertilizer)
                .length,
            upcomingHarvests: state.crops
                .where((crop) =>
                    crop.harvestWindowStart != null &&
                    crop.harvestWindowStart!.difference(today).inDays <= 14 &&
                    crop.harvestWindowStart!.isAfter(today))
                .length,
          ),
          const SizedBox(height: AppSpacing.sm),
          _CropQuickActions(
            onStartRover: () => context.push(AppRoutes.rover),
            onPastCrops: () =>
                controller.updateFilter(CropFilterType.harvested),
          ),
          const SizedBox(height: AppSpacing.xl),
          CropFilterBar(
            searchQuery: state.searchQuery,
            selectedFilter: state.selectedFilter,
            selectedSort: state.selectedSort,
            onSearchChanged: controller.updateSearch,
            onFilterChanged: controller.updateFilter,
            onSortChanged: controller.updateSort,
            onClear: controller.clearFilters,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (state.filteredCrops.isEmpty)
            const CropEmptyState()
          else
            _CropContent(
              crops: state.filteredCrops,
              onCropSelected: (crop) {
                context.push(AppRoutes.cropDetailsPath(crop.id));
              },
            ),
        ],
      ),
    );
  }
}

class _CropQuickActions extends StatelessWidget {
  const _CropQuickActions(
      {required this.onStartRover, required this.onPastCrops});
  final VoidCallback onStartRover;
  final VoidCallback onPastCrops;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CropQuickActionTile(
            icon: Icons.agriculture_outlined,
            label: 'START ROVER PLANTING',
            onPressed: onStartRover,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _CropQuickActionTile(
            icon: Icons.history,
            label: 'VIEW PAST CROPS',
            onPressed: onPastCrops,
          ),
        ),
      ],
    );
  }
}

class _CropQuickActionTile extends StatelessWidget {
  const _CropQuickActionTile({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          height: 68,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.bottomCenter,
              radius: 1.25,
              colors: AppColors.heroGradientColors,
            ),
            border: Border.all(
              color: AppColors.primaryGreen.withValues(alpha: .34),
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: .06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _CropActionStarFieldPainter()),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: AppColors.heroIconGreen, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.heroPrimaryText,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CropActionStarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const stars = <Offset>[
      Offset(.08, .18),
      Offset(.18, .54),
      Offset(.31, .26),
      Offset(.47, .66),
      Offset(.62, .2),
      Offset(.76, .5),
      Offset(.91, .28),
    ];
    final paint = Paint()..color = AppColors.accentGreen.withValues(alpha: .3);
    for (var index = 0; index < stars.length; index++) {
      final star = stars[index];
      canvas.drawCircle(
        Offset(star.dx * size.width, star.dy * size.height),
        index.isEven ? 1 : .65,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CropLoadingSkeleton extends StatelessWidget {
  const _CropLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SkeletonLine(widthFactor: 0.28, height: 28),
        const SizedBox(height: AppSpacing.lg),
        const SkeletonCard(
          height: 138,
          children: [],
        ),
        const SizedBox(height: AppSpacing.xl),
        const SkeletonCard(
          children: [
            SkeletonLine(widthFactor: 0.9),
            SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: SkeletonBlock(height: 34)),
                SizedBox(width: AppSpacing.sm),
                Expanded(child: SkeletonBlock(height: 34)),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        const SkeletonLine(widthFactor: 0.62, height: 18),
        const SizedBox(height: AppSpacing.md),
        const SkeletonCard(
          children: [
            SkeletonLine(widthFactor: 0.68),
            SizedBox(height: AppSpacing.md),
            SkeletonBlock(height: 72),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const SkeletonLine(widthFactor: 0.3, height: 18),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: const [
              SizedBox(width: 128, child: _CropTileSkeleton()),
              SizedBox(width: AppSpacing.md),
              SizedBox(width: 128, child: _CropTileSkeleton()),
              SizedBox(width: AppSpacing.md),
              SizedBox(width: 128, child: _CropTileSkeleton()),
            ],
          ),
        ),
      ],
    );
  }
}

class _CropTileSkeleton extends StatelessWidget {
  const _CropTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SkeletonCard(
      children: [
        SkeletonLine(widthFactor: 0.7),
        SizedBox(height: AppSpacing.md),
        Center(child: SkeletonBlock(height: 58, width: 58)),
        SizedBox(height: AppSpacing.md),
        SkeletonLine(widthFactor: 0.85),
        SizedBox(height: AppSpacing.sm),
        SkeletonBlock(height: 28),
      ],
    );
  }
}

class _CropContent extends StatelessWidget {
  const _CropContent({
    required this.crops,
    required this.onCropSelected,
  });

  final List<CropModel> crops;
  final ValueChanged<CropModel> onCropSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in _groupCropsByPlant(crops).entries) ...[
          PlantedCropGroup(
            title: '${group.key} (${group.value.length})',
            crops: group.value,
            onCropSelected: onCropSelected,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }

  Map<String, List<CropModel>> _groupCropsByPlant(List<CropModel> crops) {
    final sortedCrops = [...crops]..sort((left, right) {
        final plantCompare = left.name.compareTo(right.name);

        if (plantCompare != 0) {
          return plantCompare;
        }

        return right.plantingDate.compareTo(left.plantingDate);
      });
    final grouped = <String, List<CropModel>>{};

    for (final crop in sortedCrops) {
      grouped.putIfAbsent(crop.name, () => []).add(crop);
    }

    return grouped;
  }
}
