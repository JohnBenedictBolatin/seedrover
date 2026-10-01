import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/permission_keys.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/content_skeleton.dart';
import '../../data/models/crop_model.dart';
import '../../controllers/crop_monitoring_controller.dart';
import '../../controllers/crop_monitoring_state.dart';
import '../../providers/crop_providers.dart';
import '../widgets/crop_empty_state.dart';
import '../widgets/crop_filter_bar.dart';
import '../widgets/crop_overview_hero.dart';
import '../widgets/crop_history_button.dart';
import '../widgets/crop_screen_header.dart';
import '../widgets/crop_weather_card.dart';
import '../widgets/planted_crop_group.dart';
import '../../../../shared/widgets/seedrover_mascot.dart';
import '../../../../shared/widgets/startup_recovery.dart';
import '../../../rover/data/models/rover_command_model.dart';
import '../../../rover/data/models/planting_session_model.dart';
import '../../../rover/providers/rover_providers.dart';
import '../../../authentication/providers/auth_providers.dart';
import '../../../rover/presentation/widgets/planting_sync_progress_dialog.dart';

class CropMonitoringScreen extends ConsumerStatefulWidget {
  const CropMonitoringScreen({super.key});

  @override
  ConsumerState<CropMonitoringScreen> createState() =>
      _CropMonitoringScreenState();
}

class _CropMonitoringScreenState extends ConsumerState<CropMonitoringScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(cropMonitoringControllerProvider.notifier).retryPendingDrafts();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cropMonitoringControllerProvider);
    final controller = ref.read(cropMonitoringControllerProvider.notifier);
    final profile = ref.watch(authControllerProvider).profile;
    final plantingRunsAwaitingSync =
        ref.watch(plantingRunsAwaitingSyncProvider).asData?.value ?? const [];

    if (state.crops.isEmpty &&
        (state.isLoading || state.errorMessage != null)) {
      return StartupRecovery(
        loading: const _CropLoadingSkeleton(),
        errorMessage: state.errorMessage,
        onRetry: controller.loadCrops,
        destinations: [
          (label: 'Continue to Dashboard', route: AppRoutes.dashboard),
          if (profile?.hasPermission(PermissionKeys.roverView) == true)
            (label: 'Continue to Rover Control', route: AppRoutes.rover),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(plantingRunsAwaitingSyncProvider);
        ref.invalidate(cropWeatherProvider);
        await controller.refreshCrops();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CropScreenHeader(),
                const SizedBox(height: AppSpacing.md),
                CropOverviewHero(activeCrops: state.activeCrops),
                const SizedBox(height: AppSpacing.sm),
                CropHistoryButton(
                  client: ref.read(supabaseClientProvider),
                ),
                const SizedBox(height: AppSpacing.md),
                const CropWeatherCard(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _OfflineCropNotice(
                    message: state.errorMessage!,
                    onRetry: controller.loadCrops,
                    onDismiss: controller.clearErrorMessage,
                  ),
                ],
                _CareDraftsPanel(controller: controller),
                if (plantingRunsAwaitingSync.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _PlantingRunsAwaitingSync(
                    runs: plantingRunsAwaitingSync,
                    onSync: _syncPlantingRuns,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                CropFilterBar(
                  searchQuery: state.searchQuery,
                  selectedFilter: state.selectedFilter,
                  selectedSort: state.selectedSort,
                  onSearchChanged: controller.updateSearch,
                  onFilterChanged: controller.updateFilter,
                  onSortChanged: controller.updateSort,
                ),
                _CropActiveFilters(
                  state: state,
                  onStatusRemoved: () =>
                      controller.updateFilter(CropFilterType.all),
                  onSortRemoved: () =>
                      controller.updateSort(CropSortType.newest),
                  onClear: controller.clearFilters,
                ),
                const SizedBox(height: AppSpacing.md),
                if (state.filteredCrops.isEmpty)
                  state.crops.isEmpty
                      ? const CropEmptyState()
                      : _NoCropResults(onClear: controller.clearFilters)
                else
                  _CropContent(
                    crops: state.filteredCrops,
                    onCropSelected: (crop) {
                      context.push(AppRoutes.cropDetailsPath(crop.id));
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _syncPlantingRuns() async {
    final roverController = ref.read(roverControlControllerProvider.notifier);
    await showPlantingSyncProgressDialog(
      context,
      synchronize: roverController.synchronizePendingReceipts,
    );
    ref.invalidate(plantingRunsAwaitingSyncProvider);
    await ref.read(cropMonitoringControllerProvider.notifier).loadCrops();
    final syncError = ref.read(roverControlControllerProvider).errorMessage;
    if (syncError != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(syncError)));
    }
  }
}

class _PlantingRunsAwaitingSync extends StatelessWidget {
  const _PlantingRunsAwaitingSync({
    required this.runs,
    required this.onSync,
  });

  final List<PendingPlantingReceipt> runs;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.sunSurface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.warning.withValues(alpha: .45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_upload_outlined, color: AppColors.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${runs.length} confirmed planting run${runs.length == 1 ? '' : 's'} waiting to sync',
                    style: AppTypography.cardTitle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Saved on this device. Results sync when the app has internet; planted runs appear in your crop list after sync.',
              style: AppTypography.small,
            ),
            for (final run in runs.take(3)) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${run.config.seed.label} • ${run.config.fieldLabel.isEmpty ? 'Field not labeled' : run.config.fieldLabel}',
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '${run.status.completedDrops} of ${run.status.targetDrops} planting cycles • ${_plantingOutcomeLabel(run.confirmationOutcome)}',
                style: AppTypography.small,
              ),
            ],
            if (runs.length > 3) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('And ${runs.length - 3} more', style: AppTypography.small),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onSync,
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Retry sync'),
              ),
            ),
          ],
        ),
      );
}

String _plantingOutcomeLabel(String? outcome) => switch (outcome) {
      'row_planted' => 'Row planted',
      'some_planted' => 'Some planted',
      'none_planted' => 'None planted',
      _ => 'Confirmation pending',
    };

class _OfflineCropNotice extends StatelessWidget {
  const _OfflineCropNotice({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.sunSurface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, color: AppColors.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Showing saved crop records. $message',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.small,
              ),
            ),
            IconButton(
              tooltip: 'Retry crop sync',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Dismiss message',
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
}

class _CropActiveFilters extends StatelessWidget {
  const _CropActiveFilters({
    required this.state,
    required this.onStatusRemoved,
    required this.onSortRemoved,
    required this.onClear,
  });

  final CropMonitoringState state;
  final VoidCallback onStatusRemoved;
  final VoidCallback onSortRemoved;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasStatus = state.selectedFilter != CropFilterType.all;
    final hasSort = state.selectedSort != CropSortType.newest;
    if (!hasStatus && !hasSort) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (hasStatus)
            InputChip(
              label: Text(state.selectedFilter.label),
              onDeleted: onStatusRemoved,
              visualDensity: VisualDensity.compact,
            ),
          if (hasSort)
            InputChip(
              label: Text('Sort: ${state.selectedSort.label}'),
              onDeleted: onSortRemoved,
              visualDensity: VisualDensity.compact,
            ),
          TextButton(onPressed: onClear, child: const Text('Reset')),
        ],
      ),
    );
  }
}

class _NoCropResults extends StatelessWidget {
  const _NoCropResults({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.inactiveBorder),
        ),
        child: Row(
          children: [
            const SeedRoverMascot(
              expression: SeedRoverMascotExpression.emptyCurious,
              size: 48,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'No crops match this search or filter.',
                style: AppTypography.body,
              ),
            ),
            TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
        ),
      );
}

class _CareDraftsPanel extends StatefulWidget {
  const _CareDraftsPanel({required this.controller});
  final CropMonitoringController controller;

  @override
  State<_CareDraftsPanel> createState() => _CareDraftsPanelState();
}

class _CareDraftsPanelState extends State<_CareDraftsPanel> {
  late Future<List<Map<String, dynamic>>> _drafts;

  @override
  void initState() {
    super.initState();
    _drafts = widget.controller.careDrafts();
  }

  Future<void> _reload() async {
    setState(() => _drafts = widget.controller.careDrafts());
    await _drafts;
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _drafts,
        builder: (context, snapshot) {
          final drafts = snapshot.data ?? const <Map<String, dynamic>>[];
          if (drafts.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sync_problem_outlined,
                              color: AppColors.warning),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              '${drafts.length} saved record${drafts.length == 1 ? '' : 's'} on this phone',
                              style: AppTypography.cardTitle,
                            ),
                          ),
                        ],
                      ),
                      for (final draft in drafts)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          minVerticalPadding: AppSpacing.xs,
                          title: Text(
                            '${draft['activity_type'] ?? 'Crop activity'} • ${draft['status'] == 'Needs review' ? 'Needs attention' : 'Saved on this phone'}',
                          ),
                          subtitle: Text(
                            '${widget.controller.cropById(draft['crop_id'] as String? ?? '')?.trackingCode ?? 'Crop record'}\n'
                            '${draft['status'] == 'Needs review' ? 'This record needs attention before it can sync.' : 'Waiting for an internet connection.'}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Retry sync',
                            onPressed: () async {
                              await widget.controller
                                  .retryDraft(draft['submission_id'] as String);
                              await _reload();
                            },
                            icon: const Icon(Icons.sync),
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            await widget.controller.retryPendingDrafts();
                            await _reload();
                          },
                          icon: const Icon(Icons.sync),
                          label: const Text('Retry saved records'),
                        ),
                      ),
                    ]),
              ),
            ),
          );
        },
      );
}

class _CropLoadingSkeleton extends StatelessWidget {
  const _CropLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      children: [
        const CropScreenHeader(),
        const SizedBox(height: AppSpacing.md),
        const SkeletonCard(height: 116, children: []),
        const SizedBox(height: AppSpacing.lg),
        const SkeletonBlock(height: 48),
        const SizedBox(height: AppSpacing.md),
        const SkeletonLine(widthFactor: 0.34, height: 18),
        const SizedBox(height: AppSpacing.sm),
        const SkeletonCard(height: 96, children: []),
        const SizedBox(height: AppSpacing.sm),
        const SkeletonCard(height: 96, children: []),
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
