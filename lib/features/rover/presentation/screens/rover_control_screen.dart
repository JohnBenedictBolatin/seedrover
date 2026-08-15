import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
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
import '../../data/models/rover_control_model.dart';
import '../../data/models/planting_session_model.dart';
import '../../controllers/rover_control_controller.dart';
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
    ref.listen<RoverControlState>(roverControlControllerProvider,
        (previous, next) {
      final message = next.errorMessage;
      if (message != null &&
          message != previous?.errorMessage &&
          !message.startsWith('Scanning for')) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });
    final state = ref.watch(roverControlControllerProvider);
    final controller = ref.read(roverControlControllerProvider.notifier);
    final profile = ref.watch(authControllerProvider).profile;

    final canControl =
        profile?.hasPermission(PermissionKeys.roverControl) ?? false;
    final canViewCamera =
        profile?.hasPermission(PermissionKeys.roverCameraView) ?? false;
    final canControlPlanting =
        profile?.hasPermission(PermissionKeys.roverPlantingControl) ?? false;

    if (state.isLoading) {
      return const _RoverLoadingSkeleton();
    }

    final telemetry = state.telemetry ?? RoverControlModel.offline();

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
                    localWifiConnected: state.localWifiConnected,
                    localWifiConnecting: state.localWifiConnecting,
                    onPing: controller.pingRover,
                    isPinging: state.isPinging,
                    pingRoundTripMs: state.pingRoundTripMs,
                    onBack: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.dashboard);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: MovementControlPanel(
                            enabled: state.isPlantingLocked
                                ? canControlPlanting
                                : canControl,
                            plantingMode: state.isPlantingLocked,
                            activeCommand: state.activeMovement,
                            onCommand: controller.sendMovement,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              Expanded(
                                child: CameraPreviewPanel(
                                  connected: telemetry.cameraConnected,
                                  loading: telemetry.cameraLoading,
                                  canView: canViewCamera,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 4,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SensorMonitoringGrid(
                                  sensors: telemetry.sensors,
                                  compact: true,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                _HeaderSeedSelector(
                                  selectedSeed: state.selectedSeed,
                                  enabled: !state.isPlantingLocked,
                                  onChanged: controller.selectSeed,
                                  fillWidth: true,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                PlantingControlPanel(
                                  status: state.plantingStatus,
                                  soilCheckMessage: state.soilCheckMessage,
                                  canCheckSoil:
                                      state.canCheckSoil && canControlPlanting,
                                  canStartPlanting: state.canStartPlanting &&
                                      canControlPlanting,
                                  isPlantingActive: state.plantingStatus ==
                                          PlantingStatus.active ||
                                      (state.isPlantingLocked &&
                                          state.plantingStatus !=
                                              PlantingStatus.paused),
                                  completedDrops:
                                      state.plantingOperation?.completedDrops ??
                                          0,
                                  targetDrops:
                                      state.plantingOperation?.targetDrops ?? 0,
                                  pendingReceipts: state.pendingReceiptCount,
                                  onCheckSoil: controller.checkSoilState,
                                  onStartPlanting: () =>
                                      _showPlantingConfiguration(
                                    context,
                                    controller,
                                    state.selectedSeed,
                                  ),
                                  onCalibration: () =>
                                      _showCalibration(context, controller),
                                  onResume: controller.resumePlanting,
                                  onCancel: controller.cancelPlanting,
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
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _PingAcknowledgementBar(
                    telemetry: telemetry,
                    connected: state.localWifiConnected,
                    isPinging: state.isPinging,
                    roundTripMs: state.pingRoundTripMs,
                    errorMessage: state.errorMessage,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showPlantingConfiguration(
    BuildContext context,
    RoverControlController controller,
    PlantingSeedType selectedSeed,
  ) async {
    final configuration = await showDialog<PlantingRowConfig>(
      context: context,
      builder: (_) => _PlantingRowDialog(initialSeed: selectedSeed),
    );
    if (configuration != null) await controller.startPlanting(configuration);
  }

  Future<void> _showCalibration(
    BuildContext context,
    RoverControlController controller,
  ) async {
    try {
      final current = await controller.loadCalibration();
      if (!context.mounted) return;
      final calibration = await showDialog<RoverCalibrationModel>(
        context: context,
        builder: (_) => _CalibrationDialog(initial: current),
      );
      if (calibration != null) await controller.saveCalibration(calibration);
    } catch (_) {}
  }

  void _confirmRoverAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() onConfirm,
    Color? confirmColor,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _RoverConfirmationDialog(
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          confirmColor: confirmColor ?? AppColors.primaryGreen,
          onConfirm: () {
            Navigator.of(dialogContext).pop();
            onConfirm();
          },
        );
      },
    );
  }
}

class _PlantingRowDialog extends StatefulWidget {
  const _PlantingRowDialog({required this.initialSeed});

  final PlantingSeedType initialSeed;

  @override
  State<_PlantingRowDialog> createState() => _PlantingRowDialogState();
}

class _PlantingRowDialogState extends State<_PlantingRowDialog> {
  final _formKey = GlobalKey<FormState>();
  late PlantingSeedType _seed;
  late TextEditingController _field;
  late TextEditingController _drops;
  late TextEditingController _spacing;
  late TextEditingController _rowSpacing;
  late TextEditingController _gateMs;
  late TextEditingController _rakeOffset;
  late TextEditingController _seedMin;
  late TextEditingController _seedMax;

  @override
  void initState() {
    super.initState();
    _seed = widget.initialSeed;
    _setDefaults(resetField: true);
  }

  void _setDefaults({bool resetField = false}) {
    final defaults = PlantingRowConfig.defaults(_seed);
    if (resetField) _field = TextEditingController();
    _drops = TextEditingController(text: defaults.targetDrops.toString());
    _spacing =
        TextEditingController(text: defaults.spacingCm.toStringAsFixed(0));
    _rowSpacing =
        TextEditingController(text: defaults.rowSpacingCm.toStringAsFixed(0));
    _gateMs = TextEditingController(text: defaults.gateOpenMs.toString());
    _rakeOffset =
        TextEditingController(text: defaults.rakeOffsetCm.toStringAsFixed(0));
    _seedMin = TextEditingController(
        text: defaults.estimatedSeedsPerDropMin.toString());
    _seedMax = TextEditingController(
        text: defaults.estimatedSeedsPerDropMax.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CONFIGURE PLANTING ROW', style: AppTypography.cardTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(
                    'The rover counts gate pulses as completed drops. Seed totals remain estimates.',
                    style: AppTypography.body
                        .copyWith(color: AppColors.secondaryText)),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<PlantingSeedType>(
                  value: _seed,
                  decoration: _fieldDecoration('CROP PROFILE'),
                  items: PlantingSeedType.values
                      .map((seed) => DropdownMenuItem(
                          value: seed, child: Text(seed.label)))
                      .toList(),
                  onChanged: (seed) {
                    if (seed == null) return;
                    setState(() {
                      _seed = seed;
                      _setDefaults();
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _field,
                  decoration: _fieldDecoration('FIELD OR BED',
                      hint: 'e.g. North Field - Row 3'),
                  validator: _requiredText,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _numberField(_drops, 'TARGET DROPS', whole: true),
                    _numberField(_spacing, 'DROP SPACING (CM)'),
                    _numberField(_rowSpacing, 'ROW SPACING (CM)'),
                    _numberField(_gateMs, 'GATE OPEN (MS)', whole: true),
                    _numberField(_rakeOffset, 'RAKE TO GATE (CM)',
                        allowZero: true),
                    _numberField(_seedMin, 'EST. SEEDS / PULSE MIN',
                        whole: true),
                    _numberField(_seedMax, 'EST. SEEDS / PULSE MAX',
                        whole: true),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CANCEL')),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                        onPressed: _submit, child: const Text('START ROW')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SizedBox _numberField(TextEditingController controller, String label,
      {bool whole = false, bool allowZero = false}) {
    return SizedBox(
      width: 210,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: !whole),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
              whole ? RegExp(r'[0-9]') : RegExp(r'[0-9.]')),
        ],
        decoration: _fieldDecoration(label),
        validator: (value) {
          final number = double.tryParse(value ?? '');
          if (number == null || (allowZero ? number < 0 : number <= 0)) {
            return 'Enter a valid non-negative value';
          }
          if (whole && number != number.roundToDouble()) {
            return 'Use a whole number';
          }
          return null;
        },
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final minSeeds = int.parse(_seedMin.text);
    final maxSeeds = int.parse(_seedMax.text);
    if (maxSeeds < minSeeds) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Maximum estimated seeds must be at least the minimum.')));
      return;
    }
    final defaults = PlantingRowConfig.defaults(_seed);
    Navigator.pop(
      context,
      PlantingRowConfig(
        sessionId: defaults.sessionId,
        seed: _seed,
        fieldLabel: _field.text.trim(),
        targetDrops: int.parse(_drops.text),
        spacingCm: double.parse(_spacing.text),
        rowSpacingCm: double.parse(_rowSpacing.text),
        gateOpenMs: int.parse(_gateMs.text),
        rakeOffsetCm: double.parse(_rakeOffset.text),
        estimatedSeedsPerDropMin: minSeeds,
        estimatedSeedsPerDropMax: maxSeeds,
      ),
    );
  }
}

class _CalibrationDialog extends StatefulWidget {
  const _CalibrationDialog({required this.initial});
  final RoverCalibrationModel initial;

  @override
  State<_CalibrationDialog> createState() => _CalibrationDialogState();
}

class _CalibrationDialogState extends State<_CalibrationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _values = [
    TextEditingController(
        text: widget.initial.leftTicksPerMeter.toStringAsFixed(0)),
    TextEditingController(
        text: widget.initial.rightTicksPerMeter.toStringAsFixed(0)),
    TextEditingController(text: widget.initial.soilDryRaw.toString()),
    TextEditingController(text: widget.initial.soilWetRaw.toString()),
    TextEditingController(text: widget.initial.rakeToGateCm.toStringAsFixed(1)),
  ];

  @override
  Widget build(BuildContext context) {
    const labels = [
      'LEFT TICKS OVER 1 METER',
      'RIGHT TICKS OVER 1 METER',
      'DRY SOIL RAW READING',
      'WET SOIL RAW READING',
      'RAKE TO SEED GATE (CM)'
    ];
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ROVER CALIBRATION', style: AppTypography.cardTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(
                    'Roll each wheel exactly one meter, then enter the measured encoder ticks. Record the soil probe in known dry and wet soil.',
                    style: AppTypography.body
                        .copyWith(color: AppColors.secondaryText)),
                const SizedBox(height: AppSpacing.md),
                for (var index = 0; index < _values.length; index++) ...[
                  TextFormField(
                    controller: _values[index],
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                    decoration: _fieldDecoration(labels[index]),
                    validator: (value) => double.tryParse(value ?? '') == null
                        ? 'Enter a valid non-negative number'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CANCEL')),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                        onPressed: _save,
                        child: const Text('SAVE CALIBRATION')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final dry = int.parse(_values[2].text);
    final wet = int.parse(_values[3].text);
    if (dry == wet) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dry and wet readings must differ.')));
      return;
    }
    Navigator.pop(
        context,
        RoverCalibrationModel(
          leftTicksPerMeter: double.parse(_values[0].text),
          rightTicksPerMeter: double.parse(_values[1].text),
          soilDryRaw: dry,
          soilWetRaw: wet,
          rakeToGateCm: double.parse(_values[4].text),
        ));
  }
}

InputDecoration _fieldDecoration(String label, {String? hint}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      isDense: true,
    );

String? _requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required' : null;

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

class _PingAcknowledgementBar extends StatelessWidget {
  const _PingAcknowledgementBar({
    required this.telemetry,
    required this.connected,
    required this.isPinging,
    required this.roundTripMs,
    required this.errorMessage,
  });

  final RoverControlModel telemetry;
  final bool connected;
  final bool isPinging;
  final int? roundTripMs;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final acknowledged = roundTripMs != null;
    final Color color;
    final IconData icon;
    final String message;

    if (isPinging) {
      color = AppColors.warning;
      icon = Icons.network_ping;
      message = 'PING sent - waiting for ESP32 acknowledgement...';
    } else if (acknowledged) {
      color = AppColors.primaryGreen;
      icon = Icons.check_circle_outline;
      message = 'PING accepted - PONG received in $roundTripMs ms';
    } else if (errorMessage != null) {
      color = AppColors.danger;
      icon = Icons.error_outline;
      message = 'PING failed - $errorMessage';
    } else if (connected) {
      color = AppColors.primaryGreen;
      icon = Icons.wifi;
      message = 'ESP32 connected - ready to PING';
    } else {
      color = AppColors.mutedText;
      icon = Icons.wifi_off;
      message = 'Connect to the ESP32 to test PING latency';
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.inactiveBorder),
      ),
      child: Row(
        children: [
          RoverStatusGrid(telemetry: telemetry, compact: true),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 1,
            height: 18,
            color: AppColors.inactiveBorder,
          ),
          const SizedBox(width: AppSpacing.sm),
          if (isPinging)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          else
            Icon(icon, size: 17, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.monoCaption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoverHeader extends StatelessWidget {
  const _RoverHeader({
    required this.connected,
    required this.localWifiConnected,
    required this.localWifiConnecting,
    required this.onPing,
    required this.isPinging,
    required this.pingRoundTripMs,
    required this.onBack,
  });

  final bool connected;
  final bool localWifiConnected;
  final bool localWifiConnecting;
  final Future<void> Function() onPing;
  final bool isPinging;
  final int? pingRoundTripMs;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: 'Back',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.arrow_back),
          color: AppColors.primaryText,
        ),
        const SizedBox(width: AppSpacing.xs),
        AnimatedTypingText(
          'Rover Control',
          style: AppTypography.screenTitle.copyWith(fontSize: 26),
        ),
        const SizedBox(width: AppSpacing.md),
        AnimatedTypingText(
          connected ? 'ROVER ONLINE' : 'OFFLINE',
          style: AppTypography.monoCaption.copyWith(
            color: connected ? AppColors.primaryGreen : AppColors.warning,
          ),
        ),
        const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.outlined(
              onPressed: isPinging ? null : onPing,
              tooltip: isPinging ? 'PING in progress' : 'PING rover',
              icon: isPinging
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.network_ping, size: 18),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.square(32),
                maximumSize: const Size.square(32),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            if (pingRoundTripMs != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${pingRoundTripMs}ms',
                style: AppTypography.monoCaption.copyWith(
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
        _LocalWifiStatus(
          connected: localWifiConnected,
          connecting: localWifiConnecting,
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
    this.fillWidth = false,
  });

  final PlantingSeedType selectedSeed;
  final bool enabled;
  final ValueChanged<PlantingSeedType> onChanged;
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.inactiveBorder),
      ),
      child: SizedBox(
        width: fillWidth ? double.infinity : 154,
        height: 32,
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
              Text(
                'SEED',
                style: AppTypography.monoCaption.copyWith(
                  color: AppColors.secondaryText,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
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

class _LocalWifiStatus extends StatelessWidget {
  const _LocalWifiStatus({
    required this.connected,
    required this.connecting,
  });

  final bool connected;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.primaryGreen : AppColors.mutedText;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border.all(color: AppColors.inactiveBorder),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (connecting)
            const SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              connected ? Icons.wifi : Icons.wifi_find,
              size: 16,
              color: color,
            ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            connecting
                ? 'Detecting SeedRover'
                : connected
                    ? 'SeedRover connected'
                    : 'Waiting for SeedRover',
            style: AppTypography.monoCaption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
