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
    super.key,
  });

  final bool enabled;
  final RoverMovementCommand? activeCommand;
  final ValueChanged<RoverMovementCommand> onCommand;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Center(
        child: _DirectionalPad(
          enabled: enabled,
          activeCommand: activeCommand,
          onCommand: onCommand,
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
  });

  final bool enabled;
  final RoverMovementCommand? activeCommand;
  final ValueChanged<RoverMovementCommand> onCommand;

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
                  enabled: enabled,
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
                        enabled: enabled,
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
                        enabled: enabled,
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
                  enabled: enabled,
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
    final boundedWidth = availableWidth.clamp(156.0, 260.0).toDouble();
    final boundedHeight = availableHeight.clamp(156.0, 260.0).toDouble();

    return boundedWidth < boundedHeight ? boundedWidth : boundedHeight;
  }
}

class _ArrowButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.primaryGreen;

    return Tooltip(
      message: command.label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: selected ? color : AppColors.inactiveBorder),
        ),
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final shortestSide = constraints.biggest.shortestSide;
              final iconSize =
                  (shortestSide * 0.42).clamp(24.0, 34.0).toDouble();

              return IconButton(
                onPressed: enabled ? () => onCommand(command) : null,
                icon: Icon(
                  icon,
                  color: selected ? color : null,
                  size: iconSize,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
