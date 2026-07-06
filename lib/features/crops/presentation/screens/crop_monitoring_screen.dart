import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/content_skeleton.dart';
import '../../data/models/crop_model.dart';
import '../../providers/crop_providers.dart';
import '../widgets/crop_empty_state.dart';
import '../widgets/crop_filter_bar.dart';
import '../widgets/crop_screen_header.dart';
import '../widgets/planted_crop_group.dart';
import '../widgets/planted_today_card.dart';

class CropMonitoringScreen extends ConsumerWidget {
  const CropMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cropMonitoringControllerProvider);
    final controller = ref.read(cropMonitoringControllerProvider.notifier);

    if (state.isLoading) {
      return const _CropLoadingSkeleton();
    }

    if (state.errorMessage != null) {
      return Center(
        child: Text(state.errorMessage!, style: AppTypography.body),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refreshCrops,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const CropScreenHeader(),
          const SizedBox(height: AppSpacing.xl),
          CropFilterBar(
            searchQuery: state.searchQuery,
            selectedCropName: state.selectedCropName,
            selectedPlantingDate: state.selectedPlantingDate,
            selectedGrowthStage: state.selectedGrowthStage,
            cropNames: state.cropNames,
            plantingDates: state.plantingDates,
            onSearchChanged: controller.updateSearch,
            onCropNameChanged: controller.updateCropName,
            onPlantingDateChanged: controller.updatePlantingDate,
            onGrowthStageChanged: controller.updateGrowthStage,
            onClear: controller.clearFilters,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Planted Today, May 19, 2026',
            style: AppTypography.cardTitle,
          ),
          const SizedBox(height: AppSpacing.md),
          if (state.crops.isNotEmpty)
            PlantedTodayCard(
              crop: state.crops.firstWhere(
                (crop) => crop.name == 'Calamansi',
                orElse: () => state.crops.first,
              ),
              onView: () {
                final crop = state.crops.firstWhere(
                  (crop) => crop.name == 'Calamansi',
                  orElse: () => state.crops.first,
                );
                context.push(AppRoutes.cropDetailsPath(crop.id));
              },
            ),
          const SizedBox(height: AppSpacing.lg),
          if (state.filteredCrops.isEmpty)
            CropEmptyState(onClearFilters: controller.clearFilters)
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

class _CropLoadingSkeleton extends StatelessWidget {
  const _CropLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const SkeletonLine(widthFactor: 0.28, height: 28),
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
    final sortedCrops = [...crops]
      ..sort((left, right) {
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
