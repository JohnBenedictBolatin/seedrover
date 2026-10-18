import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Shows one compact progress indicator over a page-shaped skeleton.
class InitialLoadingSkeleton extends StatefulWidget {
  const InitialLoadingSkeleton({
    required this.skeleton,
    required this.label,
    super.key,
  });

  final Widget skeleton;
  final String label;

  @override
  State<InitialLoadingSkeleton> createState() => _InitialLoadingSkeletonState();
}

class _InitialLoadingSkeletonState extends State<InitialLoadingSkeleton> {
  Timer? _slowTimer;
  bool _isSlow = false;

  @override
  void initState() {
    super.initState();
    _startSlowTimer();
  }

  @override
  void didUpdateWidget(covariant InitialLoadingSkeleton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label) {
      _isSlow = false;
      _startSlowTimer();
    }
  }

  void _startSlowTimer() {
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _isSlow = true);
    });
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _isSlow
        ? 'This is taking longer than usual. Please wait.'
        : widget.label;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(child: widget.skeleton),
        Center(
          child: Semantics(
            container: true,
            liveRegion: true,
            label: message,
            child: ExcludeSemantics(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                margin: const EdgeInsets.all(AppSpacing.lg),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground.withValues(alpha: .96),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .08),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (reduceMotion)
                      Icon(Icons.hourglass_top_rounded,
                          color: AppColors.primaryGreen, size: 22)
                    else
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        message,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
