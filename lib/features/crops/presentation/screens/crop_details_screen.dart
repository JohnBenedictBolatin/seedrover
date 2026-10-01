import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/permission_keys.dart';
import '../../../../core/constants/workspace_action.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../authentication/providers/auth_providers.dart';
import '../../controllers/crop_monitoring_controller.dart';
import '../../data/models/crop_model.dart';
import '../../providers/crop_providers.dart';
import '../widgets/crop_task_forms.dart';
import '../widgets/crop_photo_history.dart';
import '../widgets/crop_detail_panel.dart';
import '../widgets/crop_maintenance_timeline.dart';
import '../widgets/crop_plant_image.dart';
import '../widgets/crop_growth_progress.dart';
import 'crop_sensor_history_screen.dart';

class CropDetailsScreen extends ConsumerStatefulWidget {
  const CropDetailsScreen({
    required this.cropId,
    this.taskId,
    this.initialAction,
    super.key,
  });

  final String cropId;
  final String? taskId;
  final WorkspaceAction? initialAction;

  @override
  ConsumerState<CropDetailsScreen> createState() => _CropDetailsScreenState();
}

class _CropDetailsScreenState extends ConsumerState<CropDetailsScreen>
    with SingleTickerProviderStateMixin {
  bool _openedLinkedTask = false;
  TabController? _controller;
  int _selectedTab = 0;

  TabController get _tabController => _controller ??= _createTabController();

  @override
  void initState() {
    super.initState();
  }

  TabController _createTabController() {
    _selectedTab =
        widget.initialAction == WorkspaceAction.observeGrowth ? 2 : 0;
    return TabController(
      length: 4,
      initialIndex: _selectedTab,
      vsync: this,
    )..addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_selectedTab != _tabController.index) {
      setState(() => _selectedTab = _tabController.index);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleTabChange);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cropMonitoringControllerProvider);
    final controller = ref.read(cropMonitoringControllerProvider.notifier);
    final profile = ref.watch(authControllerProvider).profile;
    final crop = controller.cropById(widget.cropId);

    ref.listen(cropMonitoringControllerProvider, (previous, next) {
      final message = next.successMessage;

      if (message != null && message != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            action: message.contains('kg added to')
                ? SnackBarAction(
                    label: 'View inventory',
                    onPressed: () => context.push(AppRoutes.stocks))
                : null,
          ),
        );
        ref
            .read(cropMonitoringControllerProvider.notifier)
            .clearSuccessMessage();
      }
    });

    if (state.isLoading && crop == null) {
      return const LoadingIndicator();
    }

    if (crop == null) {
      return Center(
        child: Text('Crop record not found.', style: AppTypography.body),
      );
    }

    if (!_openedLinkedTask &&
        (widget.taskId != null || widget.initialAction != null)) {
      _openedLinkedTask = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final action = widget.initialAction;
        if (action != null &&
            !(profile?.hasPermission(action.permission) ?? false)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('This task is no longer available for your account.')));
          return;
        }
        if (action == WorkspaceAction.observeGrowth) {
          _showTaskActivityDialog(context, ref, controller, crop, null,
              CropMaintenanceActivity.stageObserved);
          return;
        }
        if (action == WorkspaceAction.recordCare) {
          _showCareActivityPicker(context, ref, controller, crop);
          return;
        }
        for (final task in crop.careTasks) {
          if (task.id == widget.taskId) {
            _showTaskActivityDialog(context, ref, controller, crop, task);
            break;
          }
        }
      });
    }

    final canManage =
        profile?.hasPermission(PermissionKeys.cropsManage) ?? false;
    return Column(
      children: [
        _CropDetailsHeader(
          onBack: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go(AppRoutes.crops);
          },
        ),
        TabBar(
          controller: _tabController,
          isScrollable: false,
          tabAlignment: TabAlignment.fill,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Sensors'),
            Tab(text: 'Growth'),
            Tab(text: 'Activity'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _CropTabPage(children: [
                _CropOverviewIdentity(
                  crop: crop,
                  onCloseWithoutHarvest: canManage && !crop.isCompleted
                      ? () => _showNotHarvestedDialog(context, controller, crop)
                      : null,
                ),
                CropDetailPanel(
                  crop: crop,
                  onRecordCare: canManage && !crop.isCompleted
                      ? () => _showCareActivityPicker(
                          context, ref, controller, crop)
                      : null,
                ),
              ]),
              CropSensorHistoryScreen(
                cropId: crop.id,
                embedded: true,
                enabled: _selectedTab == 1,
              ),
              _CropTabPage(children: [
                _CropGrowthJourney(
                  crop: crop,
                  onRecordHarvest: canManage && !crop.isCompleted
                      ? () => _showHarvestDialog(context, controller, crop)
                      : null,
                ),
              ]),
              _CropTabPage(children: [
                CropActivityHistory(records: crop.maintenanceHistory),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showHarvestDialog(BuildContext context,
          CropMonitoringController controller, CropModel crop) =>
      showCropClosureForm(context, ref, controller, crop, harvest: true);

  Future<void> _showCareActivityPicker(
    BuildContext context,
    WidgetRef ref,
    CropMonitoringController controller,
    CropModel crop,
  ) async {
    final canHarvest = _hasReachedHarvestReady(crop);
    final activity = await showModalBottomSheet<CropMaintenanceActivity>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('What would you like to record?')),
          for (final choice in <(String, IconData, CropMaintenanceActivity)>[
            (
              'Watering',
              Icons.water_drop_outlined,
              CropMaintenanceActivity.watered
            ),
            (
              'Fertilizing',
              Icons.science_outlined,
              CropMaintenanceActivity.fertilized
            ),
            (
              'Field check',
              Icons.visibility_outlined,
              CropMaintenanceActivity.inspected
            ),
            (
              'Growth observation',
              Icons.timeline,
              CropMaintenanceActivity.stageObserved
            ),
            (
              'Harvest batch',
              Icons.agriculture_outlined,
              CropMaintenanceActivity.harvested
            ),
          ]) ...[
            Builder(builder: (context) {
              final enabled =
                  choice.$3 != CropMaintenanceActivity.harvested || canHarvest;
              return ListTile(
                enabled: enabled,
                leading: Icon(
                  choice.$2,
                  color: enabled ? AppColors.primaryGreen : AppColors.mutedText,
                ),
                title: Text(
                  choice.$1,
                  style: enabled ? null : TextStyle(color: AppColors.mutedText),
                ),
                subtitle: choice.$3 == CropMaintenanceActivity.harvested &&
                        !canHarvest
                    ? Text(
                        'Available at Harvest Ready',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.mutedText,
                        ),
                      )
                    : null,
                onTap: enabled
                    ? () => Navigator.pop(sheetContext, choice.$3)
                    : null,
              );
            }),
          ],
        ]),
      ),
    );
    if (activity != null && context.mounted) {
      _showTaskActivityDialog(context, ref, controller, crop, null, activity);
    }
  }

  void _showTaskActivityDialog(BuildContext context, WidgetRef ref,
      CropMonitoringController controller, CropModel crop, CropCareTask? task,
      [CropMaintenanceActivity? requestedActivity]) {
    final activity = requestedActivity ??
        switch (task?.type) {
          'Water' => CropMaintenanceActivity.watered,
          'Fertilize' => CropMaintenanceActivity.fertilized,
          'Transplant' => CropMaintenanceActivity.transplanted,
          _ => CropMaintenanceActivity.inspected,
        };
    if (activity == CropMaintenanceActivity.harvested) {
      _showHarvestDialog(context, controller, crop);
      return;
    }
    showCropCareForm(context, ref, controller, crop, activity, task);
  }

  void _showNotHarvestedDialog(BuildContext context,
          CropMonitoringController controller, CropModel crop) =>
      showCropClosureForm(context, ref, controller, crop, harvest: false);
}

class _CropDetailsHeader extends StatelessWidget {
  const _CropDetailsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: AppColors.primaryGreen,
        child: Row(
          children: [
            IconButton(
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 52),
                foregroundColor: Colors.white,
              ),
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Text(
                'Crop Details',
                style:
                    AppTypography.sectionHeading.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      );
}

class _CropOverviewIdentity extends StatelessWidget {
  const _CropOverviewIdentity({
    required this.crop,
    this.onCloseWithoutHarvest,
  });

  final CropModel crop;
  final VoidCallback? onCloseWithoutHarvest;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.eco_outlined,
                    color: AppColors.primaryGreen, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(crop.name, style: AppTypography.cardTitle),
                      Text(
                        '${crop.fieldLabel} - ${crop.trackingCode}',
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        crop.status.label,
                        style: AppTypography.caption.copyWith(
                          color: crop.status == CropStatus.needsAttention
                              ? AppColors.warning
                              : AppColors.primaryGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onCloseWithoutHarvest != null)
                  IconButton(
                    tooltip: 'Close without harvest',
                    onPressed: onCloseWithoutHarvest,
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        side: BorderSide(color: AppColors.danger),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(child: CropPlantImage(crop: crop, size: 112)),
            const SizedBox(height: AppSpacing.sm),
            CropGrowthProgress(crop: crop),
          ],
        ),
      );
}

class _CropGrowthJourney extends StatefulWidget {
  const _CropGrowthJourney({required this.crop, this.onRecordHarvest});

  final CropModel crop;
  final VoidCallback? onRecordHarvest;

  @override
  State<_CropGrowthJourney> createState() => _CropGrowthJourneyState();
}

class _CropGrowthJourneyState extends State<_CropGrowthJourney> {
  final Set<String> _expandedPhotoStages = {};

  @override
  Widget build(BuildContext context) {
    final crop = widget.crop;
    final stages = crop.profileStages;
    final harvestReadyIndex = _findStageIndex(stages, 'Harvest Ready');
    final currentStageIndex = crop.isCompleted
        ? -1
        : crop.isHarvestReady && harvestReadyIndex >= 0
            ? harvestReadyIndex
            : _findStageIndex(stages, crop.growthStageLabel);
    final stageObservations = crop.maintenanceHistory
        .where((record) =>
            record.activity == CropMaintenanceActivity.stageObserved &&
            record.observedStage?.trim().isNotEmpty == true)
        .toList()
      ..sort((a, b) => b.performedAt.compareTo(a.performedAt));
    final observations = <String, CropMaintenanceRecord>{};
    final photosByStage = <String, List<CropMaintenanceRecord>>{};
    for (final record in stageObservations) {
      final key = _normalizeStage(record.observedStage!);
      observations.putIfAbsent(key, () => record);
      if (record.photoPaths.isNotEmpty) {
        photosByStage.putIfAbsent(key, () => []).add(record);
      }
    }

    return AppCard(
      backgroundColor: AppColors.secondaryBackground,
      borderColor: AppColors.inactiveBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.eco_outlined, color: AppColors.primaryGreen, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child:
                    Text('Growth journey', style: AppTypography.sectionHeading),
              ),
              _GrowthStageBadge(
                label: crop.isCompleted ? crop.status.label : 'In progress',
                color: crop.isCompleted
                    ? AppColors.mutedText
                    : AppColors.primaryGreen,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  crop.isCompleted ? 'RECORDED STAGE' : 'CURRENT STAGE',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  crop.growthStageLabel,
                  style: AppTypography.body.copyWith(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (stages.isNotEmpty &&
                    currentStageIndex < 0 &&
                    !crop.isCompleted) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'This recorded stage is not in the crop stage plan.',
                    style: AppTypography.small,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Stage checklist', style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.sm),
          if (stages.isNotEmpty) ...[
            for (var index = 0; index < stages.length; index++)
              _GrowthStageRow(
                stage: stages[index],
                current: index == currentStageIndex,
                observation: observations[_normalizeStage(stages[index])],
                photoRecords:
                    photosByStage[_normalizeStage(stages[index])] ?? const [],
                isLast: index == stages.length - 1,
                photosExpanded: _expandedPhotoStages
                    .contains(_normalizeStage(stages[index])),
                onTogglePhotos: () {
                  final key = _normalizeStage(stages[index]);
                  setState(() {
                    if (!_expandedPhotoStages.add(key)) {
                      _expandedPhotoStages.remove(key);
                    }
                  });
                },
                onRecordHarvest: index == currentStageIndex &&
                        _normalizeStage(stages[index]) == 'harvest ready'
                    ? widget.onRecordHarvest
                    : null,
              ),
          ] else
            Text(
              'No crop-specific growth stage sequence is configured.',
              style: AppTypography.small,
            ),
          if (crop.isCompleted) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This crop is closed. Only stages with recorded observations are marked above.',
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GrowthStageRow extends StatelessWidget {
  const _GrowthStageRow({
    required this.stage,
    required this.current,
    required this.observation,
    required this.photoRecords,
    required this.isLast,
    required this.photosExpanded,
    required this.onTogglePhotos,
    required this.onRecordHarvest,
  });

  final String stage;
  final bool current;
  final CropMaintenanceRecord? observation;
  final List<CropMaintenanceRecord> photoRecords;
  final bool isLast;
  final bool photosExpanded;
  final VoidCallback onTogglePhotos;
  final VoidCallback? onRecordHarvest;

  @override
  Widget build(BuildContext context) {
    final observed = observation != null;
    final color =
        observed || current ? AppColors.primaryGreen : AppColors.inactiveBorder;
    final badgeLabel = observed
        ? 'Observed'
        : current
            ? 'Current stage'
            : 'Not recorded';
    final badgeColor =
        observed || current ? AppColors.primaryGreen : AppColors.mutedText;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: observed
                        ? AppColors.primaryGreen
                        : current
                            ? AppColors.primaryGreen.withValues(alpha: .12)
                            : AppColors.secondaryBackground,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(
                    observed
                        ? Icons.check_rounded
                        : current
                            ? Icons.radio_button_checked_rounded
                            : Icons.circle_outlined,
                    color: observed ? Colors.white : badgeColor,
                    size: current ? 14 : 17,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: observed
                          ? AppColors.primaryGreen.withValues(alpha: .55)
                          : AppColors.inactiveBorder,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: current
                      ? AppColors.primaryGreen.withValues(alpha: .06)
                      : AppColors.secondaryBackground,
                  border: Border.all(
                    color: current
                        ? AppColors.primaryGreen.withValues(alpha: .38)
                        : AppColors.inactiveBorder,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
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
                              Text(stage,
                                  style: AppTypography.body.copyWith(
                                    fontWeight: FontWeight.w700,
                                  )),
                              const SizedBox(height: 2),
                              Text(
                                observed
                                    ? 'Recorded ${DateTimeFormatter.formatDate(observation!.performedAt)}'
                                    : current
                                        ? 'Current stage in crop record'
                                        : 'No observation recorded',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _GrowthStageBadge(label: badgeLabel, color: badgeColor),
                      ],
                    ),
                    if (observed && observation!.notes.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(observation!.notes, style: AppTypography.small),
                    ],
                    if (photoRecords.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      TextButton.icon(
                        onPressed: onTogglePhotos,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                        ),
                        icon: Icon(
                          photosExpanded
                              ? Icons.visibility_off_outlined
                              : Icons.photo_library_outlined,
                          size: 18,
                        ),
                        label: Text(photosExpanded
                            ? 'Hide growth images'
                            : 'View growth images (${photoRecords.fold<int>(0, (total, record) => total + record.photoPaths.length)})'),
                      ),
                      if (photosExpanded) ...[
                        const SizedBox(height: AppSpacing.xs),
                        for (final record in photoRecords)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                for (final path in record.photoPaths)
                                  _GrowthPhotoThumbnail(
                                    path: path,
                                    stage: stage,
                                    recordedAt: record.performedAt,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ],
                    if (onRecordHarvest != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.icon(
                        onPressed: onRecordHarvest,
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('Record harvest'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'The saved harvest is added to inventory and closes this batch.',
                        style: AppTypography.caption,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowthStageBadge extends StatelessWidget {
  const _GrowthStageBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _GrowthPhotoThumbnail extends StatelessWidget {
  const _GrowthPhotoThumbnail({
    required this.path,
    required this.stage,
    required this.recordedAt,
  });

  final String path;
  final String stage;
  final DateTime recordedAt;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label:
            'View $stage growth photo recorded ${DateTimeFormatter.formatDate(recordedAt)}',
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text('$stage growth photo')),
                body: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Text(
                          DateTimeFormatter.formatDate(recordedAt),
                          style: AppTypography.caption,
                        ),
                      ),
                      Expanded(
                        child: InteractiveViewer(
                          minScale: .8,
                          maxScale: 4,
                          child: Center(
                            child: JournalPhoto(path: path, height: 520),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              width: 112,
              height: 88,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  JournalPhoto(path: path, height: 88),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .62),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.open_in_full_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

String _normalizeStage(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

bool _hasReachedHarvestReady(CropModel crop) {
  if (crop.isHarvestReady) return true;
  final readyIndex = crop.profileStages
      .indexWhere((stage) => _normalizeStage(stage) == 'harvest ready');
  final currentIndex =
      _findStageIndex(crop.profileStages, crop.growthStageLabel);
  return readyIndex >= 0 && currentIndex >= readyIndex;
}

int _findStageIndex(List<String> stages, String currentStage) {
  final normalized = _normalizeStage(currentStage);
  final exact =
      stages.indexWhere((stage) => _normalizeStage(stage) == normalized);
  if (exact >= 0) return exact;
  return stages.indexWhere((stage) =>
      normalized.contains(_normalizeStage(stage)) ||
      _normalizeStage(stage).contains(normalized));
}

class _CropTabPage extends StatelessWidget {
  const _CropTabPage({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index < children.length - 1)
                const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      );
}
