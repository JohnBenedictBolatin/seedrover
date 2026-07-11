import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/status_badge.dart';

class CameraPreviewPanel extends StatelessWidget {
  const CameraPreviewPanel({
    required this.connected,
    required this.loading,
    required this.fullscreen,
    required this.canView,
    required this.onRefresh,
    required this.onToggleFullscreen,
    super.key,
  });

  final bool connected;
  final bool loading;
  final bool fullscreen;
  final bool canView;
  final VoidCallback? onRefresh;
  final VoidCallback? onToggleFullscreen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      radius: AppRadius.sm,
      child: AspectRatio(
        aspectRatio: fullscreen ? 9 / 16 : 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primaryBackground,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: _CameraPlaceholder(
                  connected: connected && canView,
                  loading: loading,
                  canView: canView,
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                top: AppSpacing.md,
                child: StatusBadge(
                  label: connected && canView ? 'Camera Online' : 'Camera Offline',
                  color: connected && canView
                      ? AppColors.primaryGreen
                      : AppColors.inactiveBorder,
                ),
              ),
              Positioned(
                right: AppSpacing.sm,
                top: AppSpacing.sm,
                child: Row(
                  children: [
                    _CameraIconButton(
                      icon: CupertinoIcons.refresh,
                      tooltip: 'Refresh camera',
                      onPressed: canView ? onRefresh : null,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _CameraIconButton(
                      icon: fullscreen
                          ? CupertinoIcons.arrow_down_right_arrow_up_left
                          : CupertinoIcons.arrow_up_left_arrow_down_right,
                      tooltip: 'Toggle fullscreen',
                      onPressed: canView ? onToggleFullscreen : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder({
    required this.connected,
    required this.loading,
    required this.canView,
  });

  final bool connected;
  final bool loading;
  final bool canView;

  @override
  Widget build(BuildContext context) {
    if (!canView) {
      return const _CameraMessage(message: 'Camera access is not assigned.');
    }

    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }

    if (!connected) {
      return const _CameraMessage(message: 'Waiting for camera connection.');
    }

    return CustomPaint(
      painter: _CameraGridPainter(),
      child: Center(
        child: Text(
          'SIMULATED CAMERA STREAM',
          style: AppTypography.statusBadge.copyWith(
            color: AppColors.primaryGreen,
          ),
        ),
      ),
    );
  }
}

class _CameraMessage extends StatelessWidget {
  const _CameraMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTypography.small,
      ),
    );
  }
}

class _CameraIconButton extends StatelessWidget {
  const _CameraIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

class _CameraGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryGreen.withOpacity(0.12)
      ..strokeWidth = 1;

    for (var x = 0.0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (var y = 0.0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
