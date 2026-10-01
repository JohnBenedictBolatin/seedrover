import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/rover_command_model.dart';

class MovementControlPanel extends StatelessWidget {
  const MovementControlPanel({
    required this.enabled,
    required this.activeCommand,
    required this.onCommand,
    this.plantingMode = false,
    super.key,
  });

  final bool enabled;
  final RoverMovementCommand? activeCommand;
  final ValueChanged<RoverMovementCommand> onCommand;
  final bool plantingMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Center(
        child: _DirectionalPad(
          enabled: enabled,
          activeCommand: activeCommand,
          onCommand: onCommand,
          plantingMode: plantingMode,
        ),
      ),
    );
  }
}

class _DirectionalPad extends StatelessWidget {
  const _DirectionalPad({
    required this.enabled,
    required this.activeCommand,
    required this.onCommand,
    required this.plantingMode,
  });

  final bool enabled;
  final RoverMovementCommand? activeCommand;
  final ValueChanged<RoverMovementCommand> onCommand;
  final bool plantingMode;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;
        final padSize = _padSizeFor(availableWidth, availableHeight);
        final buttonSize = padSize / 3;

        return SizedBox.square(
          dimension: padSize,
          child: Column(
            children: [
              SizedBox.square(
                dimension: buttonSize,
                child: _ArrowButton(
                  icon: CupertinoIcons.arrow_up,
                  command: RoverMovementCommand.forward,
                  enabled: enabled && !plantingMode,
                  selected: activeCommand == RoverMovementCommand.forward,
                  onCommand: onCommand,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _ArrowButton(
                        icon: CupertinoIcons.arrow_left,
                        command: RoverMovementCommand.rotateLeft,
                        enabled: enabled && !plantingMode,
                        selected:
                            activeCommand == RoverMovementCommand.rotateLeft,
                        onCommand: onCommand,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _ArrowButton(
                        icon: CupertinoIcons.stop_fill,
                        command: RoverMovementCommand.stop,
                        enabled: enabled,
                        selected: true,
                        danger: true,
                        onCommand: onCommand,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _ArrowButton(
                        icon: CupertinoIcons.arrow_right,
                        command: RoverMovementCommand.rotateRight,
                        enabled: enabled && !plantingMode,
                        selected:
                            activeCommand == RoverMovementCommand.rotateRight,
                        onCommand: onCommand,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox.square(
                dimension: buttonSize,
                child: _ArrowButton(
                  icon: CupertinoIcons.arrow_down,
                  command: RoverMovementCommand.backward,
                  enabled: enabled && !plantingMode,
                  selected: activeCommand == RoverMovementCommand.backward,
                  onCommand: onCommand,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _padSizeFor(double availableWidth, double availableHeight) {
    final boundedWidth = availableWidth.clamp(140.0, 280.0).toDouble();
    final boundedHeight = availableHeight.clamp(140.0, 280.0).toDouble();

    return boundedWidth < boundedHeight ? boundedWidth : boundedHeight;
  }
}

class _ArrowButton extends StatefulWidget {
  const _ArrowButton({
    required this.icon,
    required this.command,
    required this.enabled,
    required this.selected,
    required this.onCommand,
    this.danger = false,
  });

  final IconData icon;
  final RoverMovementCommand command;
  final bool enabled;
  final bool selected;
  final bool danger;
  final ValueChanged<RoverMovementCommand> onCommand;

  @override
  State<_ArrowButton> createState() => _ArrowButtonState();
}

class _ArrowButtonState extends State<_ArrowButton> {
  int? _activePointer;

  @override
  Widget build(BuildContext context) {
    final color = widget.danger ? AppColors.danger : AppColors.primaryGreen;

    return Tooltip(
      message: widget.command.label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: widget.selected ? color : AppColors.inactiveBorder,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shortestSide = constraints.biggest.shortestSide;
            final iconSize = (shortestSide * 0.40).clamp(20.0, 30.0).toDouble();
            final arrow = Icon(
              widget.icon,
              color: widget.selected ? color : null,
              size: iconSize,
            );

            if (widget.command == RoverMovementCommand.stop) {
              return Center(
                child: IconButton(
                  tooltip: 'Stop rover',
                  onPressed: widget.enabled
                      ? () => widget.onCommand(widget.command)
                      : null,
                  icon: arrow,
                ),
              );
            }

            return Semantics(
              button: true,
              enabled: widget.enabled,
              label:
                  'Hold to ${widget.command.label.toLowerCase()}; release to stop',
              onTap: widget.enabled
                  ? () {
                      // A semantic tap has no press/release pair, so use a
                      // short, bounded pulse. Touch input below remains active
                      // for the complete time the pointer is held down.
                      widget.onCommand(widget.command);
                      Future<void>.delayed(
                        const Duration(milliseconds: 250),
                        () => widget.onCommand(RoverMovementCommand.stop),
                      );
                    }
                  : null,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: widget.enabled ? _handlePointerDown : null,
                onPointerUp: widget.enabled ? _handlePointerUp : null,
                onPointerCancel: widget.enabled ? _handlePointerCancel : null,
                child: Center(child: arrow),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    widget.onCommand(widget.command);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
    widget.onCommand(RoverMovementCommand.stop);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
    widget.onCommand(RoverMovementCommand.stop);
  }

  @override
  void dispose() {
    if (_activePointer != null) {
      _activePointer = null;
      widget.onCommand(RoverMovementCommand.stop);
    }
    super.dispose();
  }
}
