import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/animated_content.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/seedrover_mascot.dart';
import '../../../authentication/providers/auth_providers.dart';
import '../../controllers/crop_monitoring_controller.dart';
import '../../data/models/crop_model.dart';
import '../../providers/crop_providers.dart';
import '../widgets/crop_action_buttons.dart';
import '../widgets/crop_detail_panel.dart';
import '../widgets/crop_growth_timeline.dart';
import '../widgets/crop_maintenance_timeline.dart';
import '../widgets/crop_sensor_snapshot_grid.dart';

class CropDetailsScreen extends ConsumerWidget {
  const CropDetailsScreen({
    required this.cropId,
    super.key,
  });

  final String cropId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cropMonitoringControllerProvider);
    final controller = ref.read(cropMonitoringControllerProvider.notifier);
    final profile = ref.watch(authControllerProvider).profile;
    final crop = controller.cropById(cropId);

    ref.listen(cropMonitoringControllerProvider, (previous, next) {
      final message = next.successMessage;

      if (message != null && message != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        ref.read(cropMonitoringControllerProvider.notifier).clearSuccessMessage();
      }
    });

    if (state.isLoading) {
      return const LoadingIndicator();
    }

    if (crop == null) {
      return Center(
        child: Text('Crop record not found.', style: AppTypography.body),
      );
    }

    final canDelete =
        profile?.isAdministrator == true || profile?.isPlantingManager == true;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _CropDetailsHeader(
          crop: crop,
          onViewEnvironmentalInfo: () =>
              _showEnvironmentalInfoDialog(context, crop),
          onBack: () {
            if (context.canPop()) {
              context.pop();
              return;
            }

            context.go(AppRoutes.crops);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        CropDetailPanel(
          crop: crop,
          onViewGrowthTimeline: () => _showGrowthTimelineDialog(context, crop),
          actions: CropActionButtons(
            onWater: () => _showWaterDialog(context, controller, crop),
            onFertilize: () => _showFertilizeDialog(context, controller, crop),
            onHarvest: () => _confirmHarvest(context, controller, crop),
            onEdit: () => _showEditDialog(
              context,
              controller,
              crop,
              canDelete: canDelete,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _SectionCard(
          title: 'Maintenance History',
          onHistoryTap: () => _showMaintenanceHistoryDialog(context, crop),
          child: CropMaintenanceTimeline(records: crop.maintenanceHistory),
        ),
      ],
    );
  }

  void _showEnvironmentalInfoDialog(BuildContext context, CropModel crop) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return _CropStyledDialog(
          title: 'Environmental Information',
          child: CropSensorSnapshotGrid(snapshot: crop.sensorSnapshot),
        );
      },
    );
  }

  void _showGrowthTimelineDialog(BuildContext context, CropModel crop) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return _CropStyledDialog(
          title: 'Growth Timeline',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _TimelineMetricChip(
                      label: 'Age',
                      value: '${crop.cropAgeDays}d',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _TimelineMetricChip(
                      label: 'Remaining',
                      value: '${crop.remainingHarvestDays}d',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              CropGrowthTimeline(currentStage: crop.growthStage),
            ],
          ),
        );
      },
    );
  }

  void _showMaintenanceHistoryDialog(BuildContext context, CropModel crop) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return _CropStyledDialog(
          title: 'Full Maintenance History',
          child: SingleChildScrollView(
            child: CropMaintenanceTimeline(records: crop.maintenanceHistory),
          ),
        );
      },
    );
  }

  void _showWaterDialog(
    BuildContext context,
    CropMonitoringController controller,
    CropModel crop,
  ) {
    final amountController = TextEditingController();
    final notesController = TextEditingController(text: 'Watered crop.');

    _showFormDialog(
      context: context,
      title: 'Water Crop',
      fields: [
        _DialogDateLabel(date: DateTime.now()),
        TextField(
          controller: amountController,
          decoration: const InputDecoration(labelText: 'Water Amount'),
        ),
        TextField(
          controller: notesController,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
      ],
      onConfirm: () {
        controller.waterCrop(
          cropId: crop.id,
          amount: amountController.text,
          notes: notesController.text,
          date: DateTime.now(),
        );
      },
    );
  }

  void _showFertilizeDialog(
    BuildContext context,
    CropMonitoringController controller,
    CropModel crop,
  ) {
    final typeController = TextEditingController(text: 'Organic fertilizer');
    final quantityController = TextEditingController();
    final notesController = TextEditingController(text: 'Fertilizer applied.');

    _showFormDialog(
      context: context,
      title: 'Fertilize Crop',
      fields: [
        _DialogDateLabel(date: DateTime.now()),
        TextField(
          controller: typeController,
          decoration: const InputDecoration(labelText: 'Fertilizer Type'),
        ),
        TextField(
          controller: quantityController,
          decoration: const InputDecoration(labelText: 'Quantity'),
        ),
        TextField(
          controller: notesController,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
      ],
      onConfirm: () {
        controller.fertilizeCrop(
          cropId: crop.id,
          fertilizerType: typeController.text,
          quantity: quantityController.text,
          notes: notesController.text,
          date: DateTime.now(),
        );
      },
    );
  }

  void _showEditDialog(
    BuildContext context,
    CropMonitoringController controller,
    CropModel crop, {
      required bool canDelete,
    }) {
    final nameController = TextEditingController(text: crop.name);
    final varietyController = TextEditingController(text: crop.variety);
    final quantityController = TextEditingController(text: '${crop.safeSeedCount}');
    final harvestController = TextEditingController(
      text: _formatDateInput(crop.estimatedHarvest),
    );
    final staffController = TextEditingController(text: crop.managerName);
    final notesController = TextEditingController(text: crop.notes);
    var stage = crop.growthStage;
    var status = crop.status;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _CropStyledDialog(
              title: 'Edit Crop',
              child: SingleChildScrollView(
                child: _dialogFieldColumn(
                  [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Crop Name'),
                    ),
                    TextField(
                      controller: varietyController,
                      decoration: const InputDecoration(labelText: 'Variety'),
                    ),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                    TextField(
                      controller: harvestController,
                      decoration: const InputDecoration(
                        labelText: 'Estimated Harvest Date',
                        helperText: 'Use M/D/YYYY',
                      ),
                    ),
                    TextField(
                      controller: staffController,
                      decoration: const InputDecoration(labelText: 'Assigned Staff'),
                    ),
                    DropdownButtonFormField<CropGrowthStage>(
                      value: stage,
                      decoration: const InputDecoration(labelText: 'Growth Stage'),
                      items: [
                        for (final item in CropGrowthStage.values)
                          DropdownMenuItem(value: item, child: Text(item.label)),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => stage = value);
                        }
                      },
                    ),
                    DropdownButtonFormField<CropStatus>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Crop Status'),
                      items: [
                        for (final item in CropStatus.values)
                          DropdownMenuItem(value: item, child: Text(item.label)),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => status = value);
                        }
                      },
                    ),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                  ],
                ),
              ),
              actions: [
                if (canDelete)
                  _dialogActionButton(
                    label: 'Delete',
                    icon: Icons.delete_outline,
                    color: AppColors.danger,
                    onPressed: () {
                      Navigator.of(context).pop();
                      _confirmDelete(context, controller, crop);
                    },
                  ),
                _dialogActionButton(
                  label: 'Cancel',
                  color: AppColors.secondaryText,
                  borderColor: AppColors.inactiveBorder,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                _dialogActionButton(
                  label: 'Save',
                  icon: Icons.check,
                  onPressed: () {
                    final updatedCrop = crop.copyWith(
                      name: nameController.text,
                      variety: varietyController.text,
                      seedCount: int.tryParse(quantityController.text),
                      estimatedHarvest:
                          _parseDateInput(harvestController.text) ??
                              crop.estimatedHarvest,
                      managerName: staffController.text,
                      growthStage: stage,
                      status: status,
                      notes: notesController.text,
                    );

                    _showConfirmationDialog(
                      context: context,
                      title: 'Save Crop Changes',
                      message: 'Save changes to ${crop.name} ${crop.id}?',
                      onConfirm: () {
                        controller.updateCrop(updatedCrop);
                        Future<void>.microtask(
                          () => Navigator.of(context).pop(),
                        );
                      },
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmHarvest(
    BuildContext context,
    CropMonitoringController controller,
    CropModel crop,
  ) {
    _showConfirmationDialog(
      context: context,
      title: 'Harvest Crop',
      message: 'Mark ${crop.name} ${crop.id} as harvested?',
      onConfirm: () => controller.harvestCrop(crop.id),
    );
  }

  void _confirmDelete(
    BuildContext context,
    CropMonitoringController controller,
    CropModel crop,
  ) {
    _showConfirmationDialog(
      context: context,
      title: 'Delete Crop',
      message: 'Delete ${crop.name} ${crop.id}? This only affects mock data.',
      onConfirm: () {
        controller.deleteCrop(crop.id);
        context.go(AppRoutes.crops);
      },
    );
  }

  void _showFormDialog({
    required BuildContext context,
    required String title,
    required List<Widget> fields,
    required VoidCallback onConfirm,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return _CropStyledDialog(
          title: title,
          child: SingleChildScrollView(
            child: _dialogFieldColumn(fields),
          ),
          actions: [
            _dialogActionButton(
              label: 'Cancel',
              color: AppColors.secondaryText,
              borderColor: AppColors.inactiveBorder,
              onPressed: () => Navigator.of(context).pop(),
            ),
            _dialogActionButton(
              label: 'Confirm',
              icon: Icons.check,
              onPressed: () {
                onConfirm();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return _CropStyledDialog(
          title: title,
          child: SeedRoverMascotMessage(
            message: message,
            expression: title.contains('Delete')
                ? SeedRoverMascotExpression.warning
                : SeedRoverMascotExpression.thinking,
          ),
          actions: [
            _dialogActionButton(
              label: 'Cancel',
              color: AppColors.secondaryText,
              borderColor: AppColors.inactiveBorder,
              onPressed: () => Navigator.of(context).pop(),
            ),
            _dialogActionButton(
              label: 'Confirm',
              icon: Icons.check,
              onPressed: () {
                onConfirm();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _dialogActionButton({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    Color color = AppColors.primaryGreen,
    Color? borderColor,
  }) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: borderColor ?? color),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    );

    if (icon == null) {
      return OutlinedButton(
        style: style,
        onPressed: onPressed,
        child: Text(label),
      );
    }

    return OutlinedButton.icon(
      style: style,
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label),
    );
  }

  Widget _dialogFieldColumn(List<Widget> fields) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < fields.length; index++) ...[
          fields[index],
          if (index != fields.length - 1)
            const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  String _formatDateInput(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  DateTime? _parseDateInput(String value) {
    final parts = value.split('/');

    if (parts.length != 3) {
      return null;
    }

    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (month == null || day == null || year == null) {
      return null;
    }

    return DateTime(year, month, day);
  }
}

class _CropDetailsHeader extends StatelessWidget {
  const _CropDetailsHeader({
    required this.crop,
    required this.onBack,
    required this.onViewEnvironmentalInfo,
  });

  final CropModel crop;
  final VoidCallback onBack;
  final VoidCallback onViewEnvironmentalInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GreenGradient(
          child: IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _GreenGradient(
                      child: AnimatedTypingText(
                        'Details/${crop.id.replaceAll('-', '').toLowerCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.sectionHeading.copyWith(
                          color: AppColors.primaryText,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'View environmental information',
                    onPressed: onViewEnvironmentalInfo,
                    icon: const Icon(
                      Icons.info_outline,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GreenGradient extends StatelessWidget {
  const _GreenGradient({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [
            AppColors.buttonGradientStart,
            AppColors.buttonGradientEnd,
          ],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.onHistoryTap,
  });

  final String title;
  final Widget child;
  final VoidCallback? onHistoryTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.secondaryBackground,
      borderColor: AppColors.inactiveBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTypography.cardTitle)),
              IconButton(
                tooltip: 'View full history',
                onPressed: onHistoryTap,
                icon: const Icon(
                  Icons.history,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _CropStyledDialog extends StatelessWidget {
  const _CropStyledDialog({
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final maxContentHeight = MediaQuery.of(context).size.height * 0.62;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: AppCard(
        backgroundColor: AppColors.secondaryBackground,
        borderColor: AppColors.inactiveBorder,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.cardTitle.copyWith(
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxContentHeight),
              child: child,
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: actions,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelineMetricChip extends StatelessWidget {
  const _TimelineMetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.caption),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: AppTypography.sensorValue.copyWith(
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogDateLabel extends StatelessWidget {
  const _DialogDateLabel({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          'Date: ${date.month}/${date.day}/${date.year}',
          style: AppTypography.monoSmall.copyWith(
            color: AppColors.primaryGreen,
          ),
        ),
      ),
    );
  }
}
