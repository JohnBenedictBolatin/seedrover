import 'dart:async';

import 'package:flutter/material.dart';

enum FloatingNoticeTone { info, success, warning }

/// A compact, app-wide notice styled like the connectivity popup.
class FloatingAppNotice extends StatelessWidget {
  const FloatingAppNotice({
    required this.title,
    required this.message,
    this.tone = FloatingNoticeTone.info,
    this.icon,
    this.onRetry,
    this.onDismiss,
    super.key,
  });

  final String title;
  final String message;
  final FloatingNoticeTone tone;
  final IconData? icon;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = switch (tone) {
      FloatingNoticeTone.success => colors.primaryContainer,
      FloatingNoticeTone.warning => colors.tertiaryContainer,
      FloatingNoticeTone.info => colors.secondaryContainer,
    };
    final foreground = switch (tone) {
      FloatingNoticeTone.success => colors.onPrimaryContainer,
      FloatingNoticeTone.warning => colors.onTertiaryContainer,
      FloatingNoticeTone.info => colors.onSecondaryContainer,
    };
    final noticeIcon = icon ??
        switch (tone) {
          FloatingNoticeTone.success => Icons.cloud_done_rounded,
          FloatingNoticeTone.warning => Icons.cloud_off_rounded,
          FloatingNoticeTone.info => Icons.info_outline_rounded,
        };

    return Semantics(
      liveRegion: true,
      label: '$title. $message',
      child: Material(
        color: background,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: .2),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(noticeIcon, color: foreground, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: foreground),
                    ),
                    if (onRetry != null || onDismiss != null) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 0,
                        children: [
                          if (onRetry != null)
                            TextButton(
                              onPressed: onRetry,
                              style: TextButton.styleFrom(
                                foregroundColor: foreground,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('Retry'),
                            ),
                          if (onDismiss != null)
                            TextButton(
                              onPressed: onDismiss,
                              style: TextButton.styleFrom(
                                foregroundColor: foreground,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('Dismiss'),
                            ),
                        ],
                      ),
                    ],
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

OverlayEntry? _activeNoticeEntry;
Timer? _activeNoticeTimer;

/// Shows a short-lived notice above the app navigation in the root overlay.
void showFloatingAppToast(
  BuildContext context, {
  required String title,
  required String message,
  FloatingNoticeTone tone = FloatingNoticeTone.info,
  IconData? icon,
  Duration duration = const Duration(seconds: 4),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  _activeNoticeTimer?.cancel();
  _activeNoticeEntry?.remove();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) {
      final media = MediaQuery.of(overlayContext);
      final bottom = media.padding.bottom +
          (media.orientation == Orientation.landscape ? 72.0 : 86.0);
      return Stack(
        children: [
          Positioned(
            right: 12,
            bottom: bottom,
            width: (media.size.width - 24).clamp(0.0, 420.0).toDouble(),
            child: FloatingAppNotice(
              title: title,
              message: message,
              tone: tone,
              icon: icon,
            ),
          ),
        ],
      );
    },
  );
  _activeNoticeEntry = entry;
  overlay.insert(entry);
  _activeNoticeTimer = Timer(duration, () {
    entry.remove();
    if (identical(_activeNoticeEntry, entry)) _activeNoticeEntry = null;
  });
}
