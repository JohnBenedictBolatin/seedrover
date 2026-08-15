import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/authentication/providers/auth_providers.dart';
import '../../../../shared/widgets/content_skeleton.dart';
import '../../data/models/crop_model.dart';
import '../../controllers/crop_monitoring_controller.dart';
import '../../controllers/crop_monitoring_state.dart';
import '../../providers/crop_providers.dart';
import '../widgets/crop_empty_state.dart';
import '../widgets/crop_filter_bar.dart';
import '../widgets/crop_overview_hero.dart';
import '../widgets/crop_screen_header.dart';
import '../widgets/planted_crop_group.dart';
import '../widgets/planted_today_card.dart';

class CropMonitoringScreen extends ConsumerWidget {
  const CropMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cropMonitoringControllerProvider);
    final controller = ref.read(cropMonitoringControllerProvider.notifier);
    final profile = ref.watch(authControllerProvider).profile;
    final weather = ref.watch(cropWeatherProvider);
    final today = DateTime.now();
    final plantedToday = state.crops.where((crop) {
      return crop.plantingDate.year == today.year &&
          crop.plantingDate.month == today.month &&
          crop.plantingDate.day == today.day;
    }).toList();

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
          const SizedBox(height: AppSpacing.md),
          _CropQuickActions(
            canAddManual: profile?.isPlantingManager == true,
            onStartRover: () => context.push(AppRoutes.rover),
            onAddManual: () => _showManualCropDialog(context, controller),
            onPastCrops: () =>
                controller.updateFilter(CropFilterType.harvested),
          ),
          const SizedBox(height: AppSpacing.md),
          weather.when(
            data: (value) => _WeatherStrip(weather: value),
            loading: () => const LinearProgressIndicator(minHeight: 3),
            error: (_, __) => const _WeatherUnavailable(),
          ),
          const SizedBox(height: AppSpacing.lg),
          CropOverviewHero(
            activeCrops: state.activeCrops,
            wateringDue: state.crops
                .where((crop) => crop.status == CropStatus.needsWater)
                .length,
            careTasksDue: state.crops
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
          if (plantedToday.isNotEmpty) ...[
            Text(
              'Planted Today, ${_formatDate(today)}',
              style: AppTypography.cardTitle,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final crop in plantedToday) ...[
              PlantedTodayCard(
                crop: crop,
                onView: () {
                  context.push(AppRoutes.cropDetailsPath(crop.id));
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
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

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _showManualCropDialog(
      BuildContext context, CropMonitoringController controller) async {
    final values = await showDialog<_ManualCropValues>(
        context: context, builder: (_) => const _ManualCropDialog());
    if (values == null) return;
    await controller.createManualCrop(
      profileKey: values.profileKey,
      fieldLabel: values.fieldLabel,
      fieldAreaM2: values.areaM2,
      plantingDate: values.plantingDate,
      reason: values.reason,
    );
  }
}

class _WeatherStrip extends StatelessWidget {
  const _WeatherStrip({required this.weather});
  final CropWeatherSnapshot weather;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          children: [
            _WeatherValue('CURRENT WEATHER', weather.currentCondition),
            _WeatherValue('TEMPERATURE',
                weather.temperatureC == null ? '--' : '${weather.temperatureC!.toStringAsFixed(1)}°C'),
            _WeatherValue('RAIN CHANCE',
                weather.rainChancePercent == null ? '--' : '${weather.rainChancePercent!.round()}% in 24 hours'),
            _WeatherValue(
                'NEXT RAIN',
                weather.nextRainAt == null
                    ? 'No rain expected in 24 hours'
                    : _shortDate(weather.nextRainAt!)),
          ],
        ),
      ),
    );
  }

  static String _shortDate(DateTime value) =>
      '${value.month}/${value.day} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _WeatherValue extends StatelessWidget {
  const _WeatherValue(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: AppTypography.monoCaption
                  .copyWith(color: AppColors.secondaryText)),
          const SizedBox(height: 3),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.small.copyWith(fontWeight: FontWeight.w700)),
        ]),
      );
}

class _WeatherUnavailable extends StatelessWidget {
  const _WeatherUnavailable();
  @override
  Widget build(BuildContext context) => const Card(
      child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Text(
              'Weather monitoring is unavailable. Configure the farm location and try again.')));
}

class _CropQuickActions extends StatelessWidget {
  const _CropQuickActions(
      {required this.canAddManual,
      required this.onStartRover,
      required this.onAddManual,
      required this.onPastCrops});
  final bool canAddManual;
  final VoidCallback onStartRover;
  final VoidCallback onAddManual;
  final VoidCallback onPastCrops;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        FilledButton.icon(
            onPressed: onStartRover,
            icon: const Icon(Icons.agriculture_outlined),
            label: const Text('START ROVER PLANTING')),
        if (canAddManual)
          OutlinedButton.icon(
              onPressed: onAddManual,
              icon: const Icon(Icons.add),
              label: const Text('ADD MANUAL CROP')),
        OutlinedButton.icon(
            onPressed: onPastCrops,
            icon: const Icon(Icons.history),
            label: const Text('VIEW PAST CROPS')),
      ],
    );
  }
}

class _ManualCropValues {
  const _ManualCropValues(this.profileKey, this.fieldLabel, this.areaM2,
      this.plantingDate, this.reason);
  final String profileKey;
  final String fieldLabel;
  final double areaM2;
  final DateTime plantingDate;
  final String reason;
}

class _ManualCropDialog extends StatefulWidget {
  const _ManualCropDialog();
  @override
  State<_ManualCropDialog> createState() => _ManualCropDialogState();
}

class _ManualCropDialogState extends State<_ManualCropDialog> {
  final _formKey = GlobalKey<FormState>();
  final _field = TextEditingController();
  final _area = TextEditingController();
  final _reason = TextEditingController();
  String _profile = 'sitaw';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ADD MANUAL CROP'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _profile,
                decoration: const InputDecoration(
                    labelText: 'CROP PROFILE', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                      value: 'calamansi', child: Text('Calamansi')),
                  DropdownMenuItem(value: 'sitaw', child: Text('Sitaw')),
                  DropdownMenuItem(value: 'peanut', child: Text('Peanut')),
                ],
                onChanged: (value) =>
                    setState(() => _profile = value ?? _profile),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                  controller: _field,
                  decoration: const InputDecoration(
                      labelText: 'FIELD OR BED',
                      hintText: 'e.g. North Field - Row 3',
                      border: OutlineInputBorder()),
                  validator: _required),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                  controller: _area,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                      labelText: 'FIELD AREA (M2)',
                      hintText: 'e.g. 25',
                      border: OutlineInputBorder()),
                  validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0
                      ? 'Enter an area greater than zero'
                      : null),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                  controller: _reason,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'MANUAL CREATION REASON',
                      hintText: 'e.g. Rover unavailable during nursery sowing',
                      border: OutlineInputBorder()),
                  validator: _required),
              const SizedBox(height: AppSpacing.sm),
              Text(
                  'Manual crops are audit logged. Use this only when a rover planting receipt is unavailable.',
                  style: AppTypography.small
                      .copyWith(color: AppColors.secondaryText)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL')),
        FilledButton(onPressed: _submit, child: const Text('SAVE MANUAL CROP')),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
        context,
        _ManualCropValues(_profile, _field.text.trim(),
            double.parse(_area.text), DateTime.now(), _reason.text.trim()));
  }

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required' : null;
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
