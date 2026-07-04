import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/permission_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../features/authentication/providers/auth_providers.dart';
import '../../controllers/rover_control_state.dart';
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
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
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
                    errorMessage: state.errorMessage,
                    lastCommand: state.lastCommand,
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
                                onStartPlanting: controller.startPlanting,
                                onEmergencyStop: controller.emergencyStop,
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
}

class _RoverHeader extends StatelessWidget {
  const _RoverHeader({
    required this.connected,
    required this.errorMessage,
    required this.lastCommand,
  });

  final bool connected;
  final String? errorMessage;
  final String? lastCommand;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Rover Control', style: AppTypography.screenTitle),
        const SizedBox(width: AppSpacing.md),
        Text(
          connected ? 'SIM LINK ACTIVE' : 'OFFLINE',
          style: AppTypography.monoCaption.copyWith(
            color: connected ? AppColors.primaryGreen : AppColors.warning,
          ),
        ),
        const Spacer(),
        if (errorMessage != null)
          Flexible(
            child: Text(
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
            child: Text(
              'LAST: $lastCommand',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: AppTypography.monoCaption,
            ),
          ),
      ],
    );
  }
}
