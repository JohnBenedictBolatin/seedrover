import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Keeps the normal loading UI visible while offering a recovery path after
/// 15 seconds, or immediately after a confirmed initial-load failure.
class StartupRecovery extends StatefulWidget {
  const StartupRecovery({
    required this.loading,
    required this.errorMessage,
    required this.onRetry,
    required this.destinations,
    super.key,
  });

  final Widget loading;
  final String? errorMessage;
  final Future<void> Function() onRetry;
  final List<({String label, String route})> destinations;

  @override
  State<StartupRecovery> createState() => _StartupRecoveryState();
}

class _StartupRecoveryState extends State<StartupRecovery> {
  Timer? _timer;
  bool _timedOut = false;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant StartupRecovery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.errorMessage != widget.errorMessage &&
        widget.errorMessage == null &&
        !_timedOut) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 15), () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _retry() async {
    setState(() {
      _retrying = true;
      _timedOut = false;
    });
    _startTimer();
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showRecovery = widget.errorMessage != null || _timedOut;
    if (!showRecovery) return widget.loading;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * .15),
        Icon(
          widget.errorMessage == null
              ? Icons.hourglass_bottom_rounded
              : Icons.cloud_off_outlined,
          size: 42,
          color: AppColors.primaryGreen,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          widget.errorMessage == null
              ? 'Still loading your workspace'
              : 'Some data is unavailable',
          textAlign: TextAlign.center,
          style: AppTypography.sectionHeading,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          widget.errorMessage ??
              'You can retry or continue with the sections that are available.',
          textAlign: TextAlign.center,
          style: AppTypography.body,
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: _retrying ? null : _retry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_retrying ? 'Retrying…' : 'Retry'),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final destination in widget.destinations)
          TextButton(
            onPressed: () => context.go(destination.route),
            child: Text(destination.label),
          ),
      ],
    );
  }
}
