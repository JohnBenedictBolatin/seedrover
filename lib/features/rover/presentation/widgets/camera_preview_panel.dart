import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mjpeg_view/mjpeg_stream_reader.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/status_badge.dart';

class CameraPreviewPanel extends StatefulWidget {
  const CameraPreviewPanel({
    required this.connected,
    required this.loading,
    required this.canView,
    required this.cameraBaseUrl,
    this.onCameraStatusChanged,
    this.onFullscreenToggle,
    this.fillAvailableSpace = false,
    this.fullscreen = false,
    this.showStatusBadge = true,
    this.showWaitingMessage = true,
    super.key,
  });

  final bool connected;
  final bool loading;
  final bool canView;
  final String cameraBaseUrl;
  final ValueChanged<bool>? onCameraStatusChanged;
  final VoidCallback? onFullscreenToggle;
  final bool fillAvailableSpace;
  final bool fullscreen;
  final bool showStatusBadge;
  final bool showWaitingMessage;

  @override
  State<CameraPreviewPanel> createState() => _CameraPreviewPanelState();
}

class _CameraPreviewPanelState extends State<CameraPreviewPanel> {
  bool _cameraOnline = false;

  void _setCameraOnline(bool online) {
    if (_cameraOnline != online && mounted) {
      setState(() => _cameraOnline = online);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCameraStatusChanged?.call(online);
      });
    }
  }

  @override
  void didUpdateWidget(covariant CameraPreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connected != widget.connected ||
        oldWidget.canView != widget.canView ||
        oldWidget.cameraBaseUrl != widget.cameraBaseUrl) {
      _setCameraOnline(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = ClipRRect(
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
              connected: widget.connected && widget.canView,
              loading: widget.loading,
              canView: widget.canView,
              cameraBaseUrl: widget.cameraBaseUrl,
              showWaitingMessage: widget.showWaitingMessage,
              onCameraStatusChanged: _setCameraOnline,
            ),
          ),
          if (widget.showStatusBadge)
            Positioned(
              left: AppSpacing.md,
              top: AppSpacing.md,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: StatusBadge(
                  label: !widget.canView
                      ? 'Camera Restricted'
                      : _cameraOnline
                          ? 'Camera Online'
                          : 'Camera Offline',
                  color: !widget.canView
                      ? AppColors.mutedText
                      : _cameraOnline
                          ? AppColors.primaryGreen
                          : AppColors.danger,
                ),
              ),
            ),
          if (widget.onFullscreenToggle != null)
            Positioned(
              right: AppSpacing.md,
              top: AppSpacing.md,
              child: Material(
                color: AppColors.secondaryBackground.withValues(alpha: .94),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: IconButton(
                  onPressed: widget.onFullscreenToggle,
                  tooltip: widget.fullscreen
                      ? 'Exit landscape controls'
                      : 'Open landscape controls',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  iconSize: 19,
                  icon: Icon(
                    widget.fullscreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return AppCard(
      padding: EdgeInsets.zero,
      radius: AppRadius.sm,
      borderColor: AppColors.inactiveBorder,
      child: widget.fillAvailableSpace
          ? SizedBox.expand(child: preview)
          : AspectRatio(aspectRatio: 16 / 9, child: preview),
    );
  }
}

class _CameraPreview extends StatefulWidget {
  const _CameraPreview({
    required this.connected,
    required this.loading,
    required this.canView,
    required this.cameraBaseUrl,
    required this.showWaitingMessage,
    required this.onCameraStatusChanged,
  });

  final bool connected;
  final bool loading;
  final bool canView;
  final String cameraBaseUrl;
  final bool showWaitingMessage;
  final ValueChanged<bool> onCameraStatusChanged;

  @override
  State<_CameraPreview> createState() => _CameraPreviewState();
}

class _CameraPreviewState extends State<_CameraPreview>
    with WidgetsBindingObserver {
  Timer? _retryTimer;
  Timer? _frameTimeout;
  MjpegStreamReader? _reader;
  StreamSubscription<Uint8List>? _frameSubscription;
  Uint8List? _frame;
  String? _streamError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!widget.connected ||
          !widget.canView ||
          widget.cameraBaseUrl.isEmpty) {
        return;
      }
      setState(() {
        _frame = null;
        _streamError = null;
      });
      _startStream();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _stopStream();
      widget.onCameraStatusChanged(false);
    }
  }

  @override
  void didUpdateWidget(covariant _CameraPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.connected != widget.connected ||
        oldWidget.cameraBaseUrl != widget.cameraBaseUrl ||
        oldWidget.canView != widget.canView) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _stopStream();
      _frame = null;
      _streamError = null;
      if (widget.connected &&
          widget.canView &&
          widget.cameraBaseUrl.isNotEmpty) {
        _startStream();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _frameTimeout?.cancel();
    _stopStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canView) {
      return const _CameraMessage(message: 'Camera access unavailable.');
    }

    if (widget.loading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }

    if (!widget.connected || widget.cameraBaseUrl.isEmpty) {
      if (!widget.showWaitingMessage) return const SizedBox.shrink();
      return const _CameraWaitingPlaceholder();
    }

    if (_reader == null) _startStream();
    final frame = _frame;
    if (frame != null) {
      return Image.memory(frame, fit: BoxFit.cover, gaplessPlayback: true);
    }
    if (_streamError != null) {
      return _CameraMessage(message: _streamError!);
    }
    return Center(
      child: CircularProgressIndicator(color: AppColors.primaryGreen),
    );
  }

  void _startStream() {
    if (!mounted ||
        !widget.connected ||
        !widget.canView ||
        widget.cameraBaseUrl.isEmpty ||
        _reader != null) {
      return;
    }
    final baseUrl = widget.cameraBaseUrl.replaceFirst(RegExp(r'/*$'), '');
    final reader = MjpegStreamReader(
      uri: '$baseUrl/stream',
      timeout: const Duration(seconds: 8),
    );
    _reader = reader;
    _armFrameTimeout(const Duration(seconds: 8));
    _frameSubscription = reader.stream.listen(
      (frame) {
        if (!mounted || reader != _reader) return;
        _armFrameTimeout(const Duration(seconds: 5));
        setState(() {
          _frame = frame;
          _streamError = null;
        });
        widget.onCameraStatusChanged(true);
      },
      onError: (Object error) {
        if (!mounted || !identical(reader, _reader)) return;
        debugPrint('SeedRover camera stream failed at ${reader.uri}: $error');
        _handleStreamEnd(
          'Camera feed unavailable.',
          expectedReader: reader,
        );
      },
      onDone: () {
        if (!mounted || !identical(reader, _reader)) return;
        _handleStreamEnd(
          'Camera feed ended. Reconnecting…',
          expectedReader: reader,
        );
      },
    );
    reader.start();
  }

  void _handleStreamEnd(
    String message, {
    MjpegStreamReader? expectedReader,
  }) {
    if (!mounted ||
        (expectedReader != null && !identical(expectedReader, _reader))) {
      return;
    }
    _stopStream();
    _frameTimeout?.cancel();
    _frameTimeout = null;
    setState(() {
      _frame = null;
      _streamError = message;
    });
    widget.onCameraStatusChanged(false);
    _scheduleStreamRetry();
  }

  void _stopStream() {
    _frameTimeout?.cancel();
    _frameTimeout = null;
    _frameSubscription?.cancel();
    _frameSubscription = null;
    _reader?.dispose();
    _reader = null;
  }

  void _armFrameTimeout(Duration duration) {
    final reader = _reader;
    if (reader == null) return;
    _frameTimeout?.cancel();
    _frameTimeout = Timer(duration, () {
      if (mounted && identical(reader, _reader)) {
        _handleStreamEnd(
          'Camera feed unavailable. Reconnecting…',
          expectedReader: reader,
        );
      }
    });
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
      setState(() {
        _streamError = null;
      });
      _startStream();
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

class _CameraWaitingPlaceholder extends StatelessWidget {
  const _CameraWaitingPlaceholder();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 44,
                  child: Icon(
                    Icons.videocam_off_outlined,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Waiting for your rover',
                textAlign: TextAlign.center,
                style: AppTypography.small.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Connect to SeedRover Wi-Fi below to start the live feed.',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      );
}
