import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/permission_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/animated_content.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../features/authentication/providers/auth_providers.dart';
import '../../../../shared/widgets/content_skeleton.dart';
import '../../../../shared/widgets/seedrover_mascot.dart';
import '../../controllers/rover_control_state.dart';
import '../../data/models/rover_command_model.dart';
import '../../providers/rover_providers.dart';
import '../widgets/camera_preview_panel.dart';
import '../widgets/movement_control_panel.dart';
import '../widgets/planting_control_panel.dart';
import '../widgets/rover_status_grid.dart';
import '../widgets/sensor_monitoring_grid.dart';

class RoverControlScreen extends ConsumerStatefulWidget {
  const RoverControlScreen({super.key});

  @override
  ConsumerState<RoverControlScreen> createState() => _RoverControlScreenState();
}

class _RoverControlScreenState extends ConsumerState<RoverControlScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
      const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roverControlControllerProvider);
    final controller = ref.read(roverControlControllerProvider.notifier);
    final profile = ref.watch(authControllerProvider).profile;

    final canControl = profile?.hasPermission(PermissionKeys.roverControl) ?? false;
    final canViewCamera =
        profile?.hasPermission(PermissionKeys.roverCameraView) ?? false;
    final canControlPlanting =
        profile?.hasPermission(PermissionKeys.roverPlantingControl) ?? false;

    if (state.isLoading || state.telemetry == null) {
      return const _RoverLoadingSkeleton();
    }

    final telemetry = state.telemetry!;

    return Stack(
      children: [
        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _RoverHeader(
                    connected: state.isConnected,
                    selectedSeed: state.selectedSeed,
                    seedSelectorEnabled: !state.isPlantingLocked,
                    errorMessage: state.errorMessage,
                    lastCommand: state.lastCommand,
                    onSeedChanged: controller.selectSeed,
                    onConnect: controller.connectSimulation,
                    onDisconnect: controller.disconnectSimulation,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: MovementControlPanel(
                            enabled: canControl && !state.isPlantingLocked,
                            activeCommand: state.activeMovement,
                            onCommand: controller.sendMovement,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              Expanded(
                                child: CameraPreviewPanel(
                                  connected: telemetry.cameraConnected,
                                  loading: telemetry.cameraLoading,
                                  fullscreen: false,
                                  canView: canViewCamera,
                                  onRefresh: controller.refreshCamera,
                                  onToggleFullscreen:
                                      controller.toggleCameraFullscreen,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              RoverStatusGrid(
                                telemetry: telemetry,
                                compact: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SensorMonitoringGrid(
                                sensors: telemetry.sensors,
                                compact: true,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              PlantingControlPanel(
                                status: state.plantingStatus,
                                soilCheckMessage: state.soilCheckMessage,
                                canCheckSoil:
                                    state.canCheckSoil && canControlPlanting,
                                canStartPlanting:
                                    state.canStartPlanting && canControlPlanting,
                                isPlantingActive:
                                    state.plantingStatus == PlantingStatus.active,
                                onCheckSoil: controller.checkSoilState,
                                onStartPlanting: () => _confirmRoverAction(
                                  context,
                                  title: 'Start Planting',
                                  message:
                                      'Start planting ${state.selectedSeed.label} with the current soil state?',
                                  confirmLabel: 'Start',
                                  onConfirm: controller.startPlanting,
                                ),
                                onEmergencyStop: () => _confirmRoverAction(
                                  context,
                                  title: 'Emergency Stop',
                                  message:
                                      'Activate emergency stop and interrupt the current rover operation?',
                                  confirmLabel: 'Stop',
                                  confirmColor: AppColors.danger,
                                  onConfirm: controller.emergencyStop,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (state.cameraFullscreen)
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.primaryBackground,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: CameraPreviewPanel(
                    connected: telemetry.cameraConnected,
                    loading: telemetry.cameraLoading,
                    fullscreen: true,
                    canView: canViewCamera,
                    onRefresh: controller.refreshCamera,
                    onToggleFullscreen: controller.toggleCameraFullscreen,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _confirmRoverAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() onConfirm,
    Color confirmColor = AppColors.primaryGreen,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _RoverConfirmationDialog(
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          confirmColor: confirmColor,
          onConfirm: () {
            Navigator.of(dialogContext).pop();
            onConfirm();
          },
        );
      },
    );
  }
}

class _RoverConfirmationDialog extends StatelessWidget {
  const _RoverConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
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
            Text(
              title,
              style: AppTypography.cardTitle.copyWith(
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SeedRoverMascotMessage(
              message: message,
              expression: confirmColor == AppColors.danger
                  ? SeedRoverMascotExpression.warning
                  : SeedRoverMascotExpression.thinking,
            ),
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _RoverDialogButton(
                    label: 'Cancel',
                    color: AppColors.primaryText,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  _RoverDialogButton(
                    label: confirmLabel,
                    color: confirmColor,
                    icon: Icons.check,
                    onPressed: onConfirm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoverDialogButton extends StatelessWidget {
  const _RoverDialogButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
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
}

class _RoverLoadingSkeleton extends StatelessWidget {
  const _RoverLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            const Row(
              children: [
                SkeletonBlock(height: 28, width: 210),
                SizedBox(width: AppSpacing.md),
                SkeletonBlock(height: 18, width: 110),
                Spacer(),
                SkeletonBlock(height: 18, width: 150),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Expanded(
                    flex: 3,
                    child: SkeletonCard(
                      children: [
                        Spacer(),
                        Center(child: SkeletonBlock(height: 170, width: 170)),
                        Spacer(),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        Expanded(
                          child: SkeletonCard(
                            children: [
                              SkeletonLine(widthFactor: 0.36),
                              SizedBox(height: AppSpacing.md),
                              Expanded(child: SkeletonBlock(height: 140)),
                            ],
                          ),
                        ),
                        SizedBox(height: AppSpacing.sm),
                        SkeletonCard(
                          height: 86,
                          children: [
                            SkeletonLine(widthFactor: 0.7),
                            SizedBox(height: AppSpacing.sm),
                            SkeletonLine(widthFactor: 0.52),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        Expanded(
                          child: SkeletonCard(
                            children: [
                              SkeletonLine(widthFactor: 0.45),
                              SizedBox(height: AppSpacing.md),
                              SkeletonLine(widthFactor: 0.82),
                              SizedBox(height: AppSpacing.sm),
                              SkeletonLine(widthFactor: 0.68),
                              SizedBox(height: AppSpacing.sm),
                              SkeletonLine(widthFactor: 0.74),
                            ],
                          ),
                        ),
                        SizedBox(height: AppSpacing.xs),
                        SkeletonCard(
                          height: 104,
                          children: [
                            SkeletonLine(widthFactor: 0.56),
                            SizedBox(height: AppSpacing.md),
                            SkeletonBlock(height: 36),
                          ],
                        ),
                      ],
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
}

class _RoverHeader extends StatelessWidget {
  const _RoverHeader({
    required this.connected,
    required this.selectedSeed,
    required this.seedSelectorEnabled,
    required this.errorMessage,
    required this.lastCommand,
    required this.onSeedChanged,
    required this.onConnect,
    required this.onDisconnect,
  });

  final bool connected;
  final PlantingSeedType selectedSeed;
  final bool seedSelectorEnabled;
  final String? errorMessage;
  final String? lastCommand;
  final ValueChanged<PlantingSeedType> onSeedChanged;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedTypingText('Rover Control', style: AppTypography.screenTitle),
        const SizedBox(width: AppSpacing.md),
        AnimatedTypingText(
          connected ? 'SIM LINK ACTIVE' : 'OFFLINE',
          style: AppTypography.monoCaption.copyWith(
            color: connected ? AppColors.primaryGreen : AppColors.warning,
          ),
        ),
        const Spacer(),
        if (errorMessage != null)
          Flexible(
            child: AnimatedTypingText(
              errorMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: AppTypography.monoCaption.copyWith(
                color: AppColors.warning,
              ),
            ),
          )
        else if (lastCommand != null)
          Flexible(
            child: AnimatedTypingText(
              'LAST: $lastCommand',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: AppTypography.monoCaption,
            ),
          ),
        const SizedBox(width: AppSpacing.sm),
        _HeaderSeedSelector(
          selectedSeed: selectedSeed,
          enabled: seedSelectorEnabled,
          onChanged: onSeedChanged,
        ),
        const SizedBox(width: AppSpacing.sm),
        _SimulationLinkButton(
          connected: connected,
          onConnect: onConnect,
          onDisconnect: onDisconnect,
        ),
      ],
    );
  }
}

class _HeaderSeedSelector extends StatelessWidget {
  const _HeaderSeedSelector({
    required this.selectedSeed,
    required this.enabled,
    required this.onChanged,
  });

  final PlantingSeedType selectedSeed;
  final bool enabled;
  final ValueChanged<PlantingSeedType> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.inactiveBorder),
      ),
      child: SizedBox(
        width: 154,
        height: 34,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: [
              Icon(
                Icons.grass_outlined,
                color: enabled ? AppColors.primaryGreen : AppColors.mutedText,
                size: 16,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<PlantingSeedType>(
                    value: selectedSeed,
                    isExpanded: true,
                    isDense: true,
                    dropdownColor: AppColors.secondaryBackground,
                    iconEnabledColor: AppColors.primaryText,
                    iconDisabledColor: AppColors.mutedText,
                    style: AppTypography.monoCaption.copyWith(
                      color: AppColors.primaryText,
                    ),
                    onChanged: enabled
                        ? (seed) {
                            if (seed != null) {
                              onChanged(seed);
                            }
                          }
                        : null,
                    items: [
                      for (final seed in PlantingSeedType.values)
                        DropdownMenuItem(
                          value: seed,
                          child: Text(seed.label),
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

class _SimulationLinkButton extends StatelessWidget {
  const _SimulationLinkButton({
    required this.connected,
    required this.onConnect,
    required this.onDisconnect,
  });

  final bool connected;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.primaryText : AppColors.primaryGreen;

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        foregroundColor: color,
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: AppTypography.monoCaption,
      ),
      onPressed: () {
        if (connected) {
          onDisconnect();
        } else {
          onConnect();
        }
      },
      icon: Icon(
        connected ? Icons.link_off : Icons.settings_input_antenna,
        size: 16,
        color: color,
      ),
      label: Text(connected ? 'Disconnect' : 'Connect Sim'),
    );
  }
}
