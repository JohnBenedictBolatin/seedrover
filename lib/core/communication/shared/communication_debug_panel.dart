import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'communication_controller.dart';
import 'communication_providers.dart';
import 'hardware_simulator_state.dart';

class CommunicationDebugPanel extends ConsumerWidget {
  const CommunicationDebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(communicationControllerProvider);
    final connectionTime = state.connectionTime;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border.all(color: AppColors.inactiveBorder),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Communication Debug', style: AppTypography.cardTitle),
            const SizedBox(height: AppSpacing.md),
            _DebugRow(label: 'Current Connection', value: state.connectionState.label),
            _DebugRow(label: 'Current Service', value: state.activeTransport.label),
            _DebugRow(
              label: 'Current Device',
              value: state.connectedDevice?.name ?? 'None',
            ),
            _DebugRow(
              label: 'Last Command',
              value: state.lastCommand?.type.protocolName ?? 'None',
            ),
            _DebugRow(
              label: 'Last Response',
              value: state.lastResponse?.status ?? 'None',
            ),
            _DebugRow(label: 'Queue Length', value: '${state.queueLength}'),
            _DebugRow(
              label: 'Connection Time',
              value: connectionTime == null
                  ? 'Not connected'
                  : '${connectionTime.inMinutes}m ${connectionTime.inSeconds % 60}s',
            ),
            if (state.simulatorState != null) ...[
              const SizedBox(height: AppSpacing.md),
              _SimulatorControls(
                simulator: state.simulatorState!,
                controller: ref.read(communicationControllerProvider.notifier),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SimulatorControls extends StatelessWidget {
  const _SimulatorControls({
    required this.simulator,
    required this.controller,
  });

  final HardwareSimulatorState simulator;
  final CommunicationController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hardware Simulator', style: AppTypography.small),
            const SizedBox(height: AppSpacing.sm),
            _DebugRow(label: 'Activity', value: simulator.currentActivity),
            _DebugRow(label: 'Planting', value: simulator.plantingStatus),
            _DebugRow(label: 'Camera', value: simulator.cameraPlaceholder),
            _DebugRow(
              label: 'Latest Error',
              value: simulator.lastError ?? 'None',
            ),
            _SimulatorSlider(
              label: 'Battery',
              value: simulator.batteryLevel.toDouble(),
              onChanged: (value) {
                controller.setSimulatorBatteryLevel(value.round());
              },
            ),
            _SimulatorSlider(
              label: 'Seed Level',
              value: simulator.seedLevel.toDouble(),
              onChanged: (value) {
                controller.setSimulatorSeedLevel(value.round());
              },
            ),
            _SimulatorSlider(
              label: 'Soil Moisture',
              value: simulator.soilMoisture.toDouble(),
              onChanged: (value) {
                controller.setSimulatorSensorValues(soilMoisture: value);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _DebugButton(
                  label: 'Recharge',
                  onPressed: controller.rechargeSimulatorBattery,
                ),
                _DebugButton(
                  label: 'Disconnect',
                  onPressed: controller.disconnect,
                ),
                _DebugButton(
                  label: 'Reconnect',
                  onPressed: controller.reconnect,
                ),
                _DebugButton(
                  label: 'Low Battery',
                  onPressed: controller.triggerSimulatorLowBattery,
                ),
                _DebugButton(
                  label: 'Critical',
                  onPressed: controller.triggerSimulatorCriticalBattery,
                ),
                _DebugButton(
                  label: 'Conn Lost',
                  onPressed: controller.triggerSimulatorConnectionLost,
                ),
                _DebugButton(
                  label: 'Camera Fail',
                  onPressed: controller.triggerSimulatorCameraFailure,
                ),
                _DebugButton(
                  label: 'Sensor Fail',
                  onPressed: controller.triggerSimulatorSensorFailure,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _DebugRow(
              label: 'Generated Notifications',
              value: '${simulator.notifications.length}',
            ),
            _DebugRow(
              label: 'Generated Logs',
              value: '${simulator.activityLogs.length}',
            ),
          ],
        ),
      ),
    );
  }
}

class _SimulatorSlider extends StatelessWidget {
  const _SimulatorSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(label, style: AppTypography.caption),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0, 100).toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            activeColor: AppColors.primaryGreen,
            inactiveColor: AppColors.inactiveBorder,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(
            value.round().toString(),
            textAlign: TextAlign.right,
            style: AppTypography.caption.copyWith(
              color: AppColors.primaryText,
            ),
          ),
        ),
      ],
    );
  }
}

class _DebugButton extends StatelessWidget {
  const _DebugButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        foregroundColor: AppColors.primaryText,
        side: const BorderSide(color: AppColors.inactiveBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: AppTypography.caption,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _DebugRow extends StatelessWidget {
  const _DebugRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTypography.caption),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.small.copyWith(
                color: AppColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
