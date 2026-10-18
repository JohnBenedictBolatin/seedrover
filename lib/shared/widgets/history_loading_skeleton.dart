import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'content_skeleton.dart';
import 'initial_loading_skeleton.dart';

/// A wide, unboxed history-row placeholder shared by crop and inventory logs.
class HistoryLoadingSkeleton extends StatelessWidget {
  const HistoryLoadingSkeleton({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => InitialLoadingSkeleton(
        label: label,
        skeleton: const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HistoryRowPlaceholder(),
              SizedBox(height: AppSpacing.md),
              _HistoryRowPlaceholder(),
              SizedBox(height: AppSpacing.md),
              _HistoryRowPlaceholder(),
            ],
          ),
        ),
      );
}

class _HistoryRowPlaceholder extends StatelessWidget {
  const _HistoryRowPlaceholder();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBlock(width: 22, height: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Expanded(child: SkeletonBlock(height: 18)),
                      SizedBox(width: AppSpacing.sm),
                      SkeletonBlock(width: 48, height: 16),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const SkeletonBlock(width: 92, height: 12),
                  const SizedBox(height: AppSpacing.sm),
                  SkeletonBlock(
                    width: MediaQuery.sizeOf(context).width * .48,
                    height: 13,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SkeletonBlock(
                    width: MediaQuery.sizeOf(context).width * .3,
                    height: 12,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
