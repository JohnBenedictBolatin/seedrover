import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_formatter.dart';
import '../../../../shared/widgets/animated_content.dart';
import '../../../../shared/widgets/seedrover_mascot.dart';
import '../../../../shared/widgets/status_badge.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    required this.fullName,
    required this.roleName,
    required this.timestamp,
    super.key,
  });

  final String fullName;
  final String roleName;
  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GradientText(
                _greeting(timestamp),
                style: AppTypography.sectionHeading.copyWith(
                  fontSize: 18,
                  height: 24 / 18,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _GradientText(
                _firstName(fullName),
                style: AppTypography.displayHeading.copyWith(
                  fontSize: 34,
                  height: 40 / 34,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AnimatedTypingText(
                '${DateTimeFormatter.formatDate(timestamp)} '
                '${DateTimeFormatter.formatTime(timestamp)}',
                style: AppTypography.monoSmall.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              StatusBadge(label: roleName),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        const SeedRoverMascot(
          expression: SeedRoverMascotExpression.dashboard,
          size: 128,
          alignment: Alignment.centerRight,
        ),
      ],
    );
  }

  String _firstName(String value) {
    return value.trim().split(' ').first;
  }

  String _greeting(DateTime value) {
    if (value.hour < 12) {
      return 'Good morning,';
    }

    if (value.hour < 18) {
      return 'Good afternoon,';
    }

    return 'Good evening,';
  }
}

class _GradientText extends StatelessWidget {
  const _GradientText(
    this.text, {
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [
            AppColors.buttonGradientStart,
            AppColors.buttonGradientEnd,
          ],
        ).createShader(bounds);
      },
      child: AnimatedTypingText(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}
