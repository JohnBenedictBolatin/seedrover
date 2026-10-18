import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'initial_loading_skeleton.dart';

/// Keeps the page skeleton visible until data loads or a request fails.
class StartupRecovery extends StatefulWidget {
  const StartupRecovery({
    required this.loading,
    required this.errorMessage,
    required this.onRetry,
    required this.destinations,
    this.loadingLabel = 'Loading your workspace…',
    super.key,
  });

  final Widget loading;
  final String? errorMessage;
  final Future<void> Function() onRetry;
  final List<({String label, String route})> destinations;
  final String loadingLabel;

  @override
  State<StartupRecovery> createState() => _StartupRecoveryState();
}

class _StartupRecoveryState extends State<StartupRecovery> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() {
      _retrying = true;
    });
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.errorMessage == null) {
      return InitialLoadingSkeleton(
        skeleton: widget.loading,
        label: widget.loadingLabel,
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * .15),
        Icon(
          Icons.cloud_off_outlined,
          size: 42,
          color: AppColors.primaryGreen,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Some data is unavailable',
          textAlign: TextAlign.center,
          style: AppTypography.sectionHeading,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          widget.errorMessage!,
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
