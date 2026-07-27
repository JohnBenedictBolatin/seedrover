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
    required this.canView,
    super.key,
  });

  final bool connected;
  final bool loading;
  final bool canView;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      radius: AppRadius.sm,
      child: AspectRatio(
        aspectRatio: 16 / 9,
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
