import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mjpeg_view/mjpeg_view.dart';

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
    required this.cameraBaseUrl,
    super.key,
  });

  final bool connected;
  final bool loading;
  final bool canView;
  final String cameraBaseUrl;

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
                child: _CameraPreview(
                  connected: connected && canView,
                  loading: loading,
                  canView: canView,
                  cameraBaseUrl: cameraBaseUrl,
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                top: AppSpacing.md,
                child: StatusBadge(
                  label: !canView
                      ? 'Camera Restricted'
                      : connected
                          ? 'Rover Network Ready'
                          : 'Camera Offline',
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

class _CameraPreview extends StatefulWidget {
  const _CameraPreview({
    required this.connected,
    required this.loading,
    required this.canView,
    required this.cameraBaseUrl,
  });

  final bool connected;
  final bool loading;
  final bool canView;
  final String cameraBaseUrl;

  @override
  State<_CameraPreview> createState() => _CameraPreviewState();
}

class _CameraPreviewState extends State<_CameraPreview> {
  Timer? _retryTimer;
  int _streamGeneration = 0;

  @override
  void didUpdateWidget(covariant _CameraPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connected != widget.connected ||
        oldWidget.cameraBaseUrl != widget.cameraBaseUrl ||
        oldWidget.canView != widget.canView) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _streamGeneration++;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canView) {
      return const _CameraMessage(message: 'Camera access is not assigned.');
    }

    if (widget.loading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }

    if (!widget.connected || widget.cameraBaseUrl.isEmpty) {
      return const _CameraMessage(message: 'Waiting for camera connection.');
    }

    final baseUrl = widget.cameraBaseUrl.replaceFirst(RegExp(r'/*$'), '');
    return MjpegView(
      key: ValueKey('$baseUrl|${widget.connected}|$_streamGeneration'),
      uri: '$baseUrl/stream',
      fit: BoxFit.cover,
      fps: 12,
      timeout: const Duration(seconds: 5),
      loadingWidget: (_) => Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
      errorWidget: (_) => _streamError(
        'Camera feed unavailable. Connect to SeedRover-01 and check the camera connection.',
      ),
      doneWidget: (_) => _streamError(
        'Camera feed ended. Connect to SeedRover-01 and check the camera connection.',
      ),
    );
  }

  Widget _streamError(String message) {
    _scheduleStreamRetry();
    return _CameraMessage(message: message);
  }

  void _scheduleStreamRetry() {
    if (_retryTimer != null) return;

    _retryTimer = Timer(const Duration(seconds: 2), () {
      _retryTimer = null;
      if (!mounted ||
          !widget.connected ||
          !widget.canView ||
          widget.cameraBaseUrl.isEmpty) {
        return;
      }
      setState(() => _streamGeneration++);
    });
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
